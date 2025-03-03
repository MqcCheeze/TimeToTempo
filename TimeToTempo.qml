//====================================================================================================
// TimeToTempo Plugin for Musescore
// Credit to all the help I got from other developers and the Musescore devs while making this plugin.
// This plugin is free software. You can redistribute it and/or modify it.
//====================================================================================================

import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.3
import QtQuick.Layouts 1.1
import QtQuick.Window 2.2
import Qt.labs.settings 1.0
import QtQuick.Dialogs 1.1

import MuseScore 3.0

MuseScore {
      version: "1.1"
      menuPath: "Plugins.TimeToTempo"
      description: "Place a tempo marking on the selected note to match the duration desired"
      pluginType: "dialog"
      requiresScore: true
      id: 'pluginId'
     
      width:  314
      height: 240
     
      onRun: {
            console.log("Plugin loaded...");
            var cursor = curScore.newCursor();
            cursor.rewindToTick(getTick(curScore.selection.elements[0]));
            console.log(cursor.track);
      }

      function calculateTempo() {

            // Get currently seelected element
            var currentElement = curScore.selection.elements[0];
            
            if (currentElement == null) {
                  showMessage("Warning", "Please select a note head...", "Warning");
                  return;
            }
                    
            var startTimeValues;
            var endTimeValues;    
            var durationTimeValues;
            
            var startTime;
            var endTime;

            if (durationTimeInput.text == "" || durationTimeInput.text == null) {
                  // Read input times
                  startTime = startingTimeValue.text;
                  endTime = endingTimeValue.text;
            
                  // Check if the starting time and the ending time are filled
                  if (startTime == "" || endTime == "") {
                        var msg = (startTime == "") ? "Start time is empty..." : "End time is empty...";
                        showMessage("Error", msg, "Critical");
                        return;
                  }
                  
                  // Check if the starting and ending time are the same
                  if (startTime == endTime) {
                        showMessage("Error", "Start time and end time are the same...", "Critical");
                        return;
                  }
                  
                  // Parse starting time values and check if they are correctly formatted
                  startTimeValues = parseTimeToArray(startTime);
                  if (startTimeValues.length == 0) {
                        return;
                  }
                  
                  // Parse ending time values and check if they are correctly formatted
                  endTimeValues = parseTimeToArray(endTime);
                  if (endTimeValues.length == 0) {
                        return;
                  }

                  // Parse duration time values and check it is negative
                  durationTimeValues = calculateDuration(startTimeValues, endTimeValues);
                  if (durationTimeValues.length == 0) {
                        return;
                  }
            } else {
                  // Parse starting time values and check if they are correctly formatted
                  durationTimeValues = parseTimeToArray(durationTimeInput.text);
                  if (durationTimeValues.length == 0) {
                        return;
                  }
            }

            
            
            var currentNoteDurationObj; 
            var currentNoteDuration;
            
            // Handle note duration if the note is part of a tuple or not
            if (currentElement.parent.tuplet) {
                  console.log("TUPLE PARENT PARENT: " + currentElement.parent.tuplet);
                  var noteTuplet = currentElement.parent.tuplet;
                  var actualNotesTuplet = noteTuplet.actualNotes;
                  currentNoteDurationObj = noteTuplet.duration;
                  currentNoteDuration = (currentNoteDurationObj.denominator * actualNotesTuplet) / currentNoteDurationObj.numerator;
            } else {
                  currentNoteDurationObj = getChordRest(currentElement).duration;
                  currentNoteDuration = currentNoteDurationObj.denominator / currentNoteDurationObj.numerator;
            }           
            
            // Calculate the BPM
            var divisorForBeats = parseFloat(currentNoteDuration / 4);
            var durationInMilliseconds = calculateMilliseconds(durationTimeValues);
            var bpm = calculateBPM(currentNoteDuration, durationInMilliseconds);

            // Round the bpm to an integer or 2 d.p.
            bpm = (setInteger.checked) ? Math.round(bpm / 60) : (bpm / 60).toFixed(2);

            // Create a new TEMPO_TEXT and apply the BPM
            applyTempo(bpm);
      }

      function applyTempo(bpm) {
            // Get current note tick
            var currentNoteTick = getTick(curScore.selection.elements[0]);

            // Make a new cursor to manipulate
            var cursor = curScore.newCursor();
            cursor.rewindToTick(0);
            
            while(!cursor.element.staff.is(curScore.selection.elements[0].staff)) {
                  cursor.staffIdx++
            }
            cursor.track = curScore.selection.elements[0].track;
            cursor.rewindToTick(currentNoteTick);

            curScore.startCmd();
            
            // Create a new TEMPO_TEXT element
            var tempoElement = newElement(Element.TEMPO_TEXT);
            
            // Set text
            tempoElement.text = '\uECA5' + ' = ' + bpm;
            tempoElement.visible = visible;

            // Add the element to the score
            cursor.add(tempoElement);

            // This has to be done after the element is added to the score for some reason
            tempoElement.tempo = parseFloat(bpm/60);
            
            // End the command
            curScore.endCmd();

            // TO BE DONE
            //=====================================================
            // Gets the last note that is tied to this current one
            //var tiedNotes = note.lastTiedNote;
            //console.log("All tied notes: ", tiedNotes);
            //=====================================================
      
            // Set the ending time as the new starting time
            startingTimeValue.text = endingTimeValue.text;
            endingTimeValue.text = "";
            durationTimeInput.text = "";
            
            // Go to the next note
            selectPrevNext(true);
      }


      function parseTimeToArray(timeString) {
            // Split the time string at ':' and '.'
            var timeParts = timeString.split(/[:.]/);
            
            // Make sure that there are only 4 parts
            if (timeParts.length !== 4) {
                  showMessage("Error", "Invalid time format. Expected HH:MM:SS.FFF", "Critical");
                  return [];
            }
            
            // Regex for the digits 0-9
            var numberRegex = /^[0-9]+$/;
            
            try {
                  // Make sure that only digits are present otherwise spit out an error
                  for (var i = 0; i < timeParts.length; i++) {
                        if (!numberRegex.test(timeParts[i])) {
                              showMessage("Error", "Invalid characters in time input...", "Critical");
                              return [];
                        }
                  }

                  // Parse integers in Base-10
                  var hours = parseInt(timeParts[0], 10);
                  var minutes = parseInt(timeParts[1], 10);
                  var seconds = parseInt(timeParts[2], 10);
                  var milliseconds = parseInt(timeParts[3], 10);

                  // Return the time parts as an array of integers
                  return [hours, minutes, seconds, milliseconds];
            } catch (e) {
                  // Show an error message if anything goes wrong for whatever reason
                  showMessage("Error", "Error parsing time...", "Critical");
                  return [];
            } 
      }

      function calculateDuration(startValues, endValues) {
            // Calculate the duration in milliseconds
            var durationMilliseconds = calculateMilliseconds(endValues) - calculateMilliseconds(startValues);

            // Make sure duration is a positive time span
            if (durationMilliseconds < 0) {
                  showMessage("Error", "End time is earlier than start time...", "Critical");
                  return [];
            }

            // Convert the duration back into hours, minutes, seconds, and milliseconds
            var hours = Math.floor(durationMilliseconds / (3600 * 1000));
            var minutes = Math.floor((durationMilliseconds % (3600 * 1000)) / (60 * 1000));
            var seconds = Math.floor((durationMilliseconds % (60 * 1000)) / 1000);
            var milliseconds = durationMilliseconds % 1000;

            // Return the duration as [hours, minutes, seconds, milliseconds]
            return [hours, minutes, seconds, milliseconds];
      }

      // Calculate the milliseconds of a given time
      function calculateMilliseconds(values) {
            var milliseconds = (values[0] * 3600 + values[1] * 60 + values[2]) * 1000 + values[3];
            return milliseconds;
      }

      function calculateBPM(noteType, timeDur) {
            var divisorForBeats = parseFloat(noteType) / 4;

            // Time duration for each beat (in milliseconds)
            if (divisorForBeats < 1) {
                  // If note type is bigger than 1 beat
                  timeDur = timeDur / (1 / divisorForBeats);
            } else {
                  // If note type is smaller than 1 beat
                  timeDur = timeDur * divisorForBeats;
            }

            // Calculate BPM
            // note: timeDur is in milliseconds
            // note: 60 / (timeDur / 60000)
            // note: 60 seconds is 60000ms
            var bpm = 3600000 / timeDur;
            return bpm;
      }

      //====================================================================
      // FOR BELOW CODE: CREDIT GOES TO "xiaomigros" (discord) FOR THIS CODE

      // Allows identical treatment/parenthood of notes/chords/rests
      function getChordRest(element) {
            switch (element.type) {
                  case Element.NOTE: 
                        return element.parent;
                  
                  default: 
                        return element;
            }
      }
      
      // Returns the segment of a given note/chord/rest
      function getSegment(element) {
            return getChordRest(element).parent;
      }

      // Returns the tick of a given note/chord/rest/tuplet
      function getTick(element) {
            return element.type == Element.TUPLET ? getTick(element.elements[0]) : getSegment(element).tick;
      }

      // Returns readable duration values from a note/chord/rest/tuplet
      function getDuration(element) {
            return {numerator: getChordRest(element).duration.numerator, denominator: getChordRest(element).duration.denominator}
      }

      // Returns an element that the cursor can be set to select
      function getSelectableElement(element) {
            switch (element.type) {
                  case Element.CHORD: 
                        return element.notes[0];

                  default: 
                        return element;
            }
      }
      
      // Select the previous or next note 
      function selectPrevNext(next) {
            var c = curScore.newCursor();
            c.rewindToTick(0);
            // locate staff & voice of selected element
            while(!c.element.staff.is(curScore.selection.elements[0].staff)) {
                  c.staffIdx++;
            }
            c.track = curScore.selection.elements[0].track;
            
            // move cursor to position of selected element
            c.rewindToTick(getTick(curScore.selection.elements[0]));
            
            // move forwards or backwards
            if (next) {
                  c.next();
            } else {
                  c.prev();
            }
            // select the new element
            curScore.selection.select(getSelectableElement(c.element));
      }

      // FOR ABOVE CODE: CREDIT GOES TO "xiaomigros" (discord) FOR THIS CODE
      //====================================================================
      
      // GUI
      Rectangle {
            width:  360
            height: 240
            color: "#e6ebe0"

            // The grid layout for items
            GridLayout {
                  id: 'pluginGUI'
                  anchors.fill: parent
                  anchors.margins: 10
                  columns: 3
                  focus: true

                  // Starting time
                  Label { 
                        text: "Starting time:"
                        font.pixelSize: 18      
                        font.bold: true
                        color: "#ED6A5A"; 
                        
                        MouseArea{
                              anchors.fill: parent
                              onClicked:  {
                                    startingTimeValue.paste();
                              }
                        }
                  }
                  TextField {
                        id: startingTimeValue
                        Layout.columnSpan: 2
                        placeholderText: "HH:MM:SS.FFF"
                        font.pixelSize: 12
                        font.bold: true
                        
                        style: TextFieldStyle {
                              textColor: "#7F7F7F"
                              background: Rectangle {
                                    radius: 4
                                    implicitWidth: 140
                                    implicitHeight: 24
                                    border.color: "#5CA4A9"
                                    border.width: 2
                              }
                        }
                  }

                  // Ending time
                  Label {
                        text: "Ending time:"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#ED6A5A"; 
                        
                        MouseArea{
                              anchors.fill: parent
                              onClicked:  {
                                    endingTimeValue.paste();
                                    if (startingTimeValue.text != "" || startingTimeValue.text != null) {
                                          calculateTempo();
                                    }
                              }
                        }
                  }
                  TextField {
                        id: endingTimeValue
                        Layout.columnSpan: 2
                        placeholderText: "HH:MM:SS.FFF"
                        font.pixelSize: 12
                        font.bold: true
                        
                        style: TextFieldStyle {
                              textColor: "#7F7F7F"
                              background: Rectangle {
                                    radius: 4
                                    implicitWidth: 140
                                    implicitHeight: 24
                                    border.color: "#5CA4A9"
                                    border.width: 2
                              }
                        }
                  }

                  // Duration time
                  Label {
                        text: "Duration time:"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#ED6A5A"; 
                        
                        MouseArea{
                              anchors.fill: parent
                              onClicked:  {
                                    durationTimeInput.paste();
                                    calculateTempo();
                              }
                        }
                  }
                  TextField {
                        id: durationTimeInput
                        Layout.columnSpan: 2
                        placeholderText: "HH:MM:SS.FFF"
                        font.pixelSize: 12
                        font.bold: true
                        
                        style: TextFieldStyle {
                              textColor: "#7F7F7F"
                              background: Rectangle {
                                    radius: 4
                                    implicitWidth: 140
                                    implicitHeight: 24
                                    border.color: "#5CA4A9"
                                    border.width: 2
                              }
                        }
                  }
            
                  // Integer BPM
                  Label {
                        text: "Set as integer:"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#ED6A5A";
                  }
                  CheckBox {
                        id: setInteger
                        
                        style: CheckBoxStyle {
                              indicator: Rectangle {
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    radius: 4
                                    border.color: "#5CA4A9"
                                    border.width: 2
                                    
                                    Rectangle {
                                          visible: control.checked
                                          color: "#ED6A5A"
                                          radius: 2
                                          anchors.margins: 4
                                          anchors.fill: parent
                                    }
                              }
                        }
                  }
            
                  // Calculate
                  Button {
                        id: calculateButton
                        Layout.columnSpan: 3
                        text: qsTranslate("PrefsDialogBase", "Calculate")

                        style: ButtonStyle {
                              background: Rectangle {
                                    x: 20
                                    implicitWidth: 251
                                    implicitHeight: 30
                                    color: "#5CA4A9"
                                    radius: 4
                                    border.color: "#F4F1BB"
                                    border.width: 2
                              }
                              label: Text {
                                    x: 20
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#F4F1BB";
                                    text: control.text
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                              }
                        }
                        
                        onClicked: {
                              // Calculate the tempo based on the input times
                              calculateTempo();
                        }
                  }
                  
                  // Previous note
                  Button {
                        id: rewindBtn
                        Layout.columnSpan: 1
                        text: qsTranslate("PrefsDialogBase", "Previous note")

                        style: ButtonStyle {
                              background: Rectangle {
                                    x: 20
                                    implicitWidth: 100
                                    implicitHeight: 30
                                    color: "#5CA4A9"
                                    radius: 4
                                    border.color: "#F4F1BB"
                                    border.width: 2
                              }
                              
                              label: Text {
                                    x: 20
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#F4F1BB";
                                    text: control.text
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                              }
                        }
                        
                        onClicked: {
                              // Rewind and select the previous note
                              selectPrevNext(false);
                        }
                  }
            
                  // Next note
                  Button {
                        id: skipBtn
                        Layout.columnSpan: 1
                        text: qsTranslate("PrefsDialogBase", "Next note")

                        style: ButtonStyle {
                              background: Rectangle {
                                    x: 20
                                    implicitWidth: 100
                                    implicitHeight: 30
                                    color: "#5CA4A9"
                                    radius: 4
                                    border.color: "#F4F1BB"
                                    border.width: 2
                              }
                              
                              label: Text {
                                    x: 20
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#F4F1BB"
                                    text: control.text
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                              }
                        }
                        
                        onClicked: {
                              // Skip and select the next note
                              selectPrevNext(true);
                        }
                  }
            }
      }

      // Error handling popup template
      MessageDialog {
            id: msgDialog
            title: "Title"
            text: "Text"
            icon: "Information"
            Component.onCompleted: visible = false
      }
      
      // Show the message dialogue with the desired title, text and icon
      function showMessage(title, text, iconType) {
            msgDialog.title = title;
            msgDialog.text = text;
            msgDialog.icon = iconType;
            
            msgDialog.open();
      }
}