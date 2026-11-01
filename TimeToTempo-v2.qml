//====================================================================================================
// TimeToTempo v2 Plugin for Musescore
// Credit to all the help I got from other developers and the Musescore devs while making this plugin.
// This plugin is free software. You can redistribute it and/or modify it.
//====================================================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts 1.1
import MuseScore

MuseScore {
      version: "2.0.0"
      title: "TimeToTempo v2"
      description: "Place a tempo marking on the selected notes/rests to match the duration desired"
      pluginType: "dialog"
      categoryCode: "composing-arranging-tools"
      requiresScore: true
      id: 'pluginId'

      width:  314
      height: 240

      onRun: {
            console.log("Plugin loaded...");
      }

      // ---------------------------------------------------------------
      // Selection helpers (v2)
      // ---------------------------------------------------------------

      // Ticks per quarter note (MuseScore uses 480)
      function ticksPerQuarter() {
            return (typeof division === "number" && division > 0) ? division : 480;
      }

      // Converts a selected element into its chord/rest. Returns null for anything else.
      function toChordRest(element) {
            if (element == null) return null;
            switch (element.type) {
                  case Element.NOTE:
                        return element.parent;
                  case Element.CHORD:
                  case Element.REST:
                        return element;
                  default:
                        return null;
            }
      }

      // Real (sounding) length of a chord/rest in ticks, with tuplets applied.
      // NOTE: ChordRest.duration is the WRITTEN length (an eighth in a triplet reads 1/8),
      // which is what broke rests in tuplets before. actualDuration includes the tuplet ratio.
      function getChordRestTicks(cr) {
            var num;
            var den;
            var d = cr.actualDuration;

            if (d !== undefined && d !== null && d.denominator) {
                  num = d.numerator;
                  den = d.denominator;
            } else {
                  // Fallback: written duration scaled by every enclosing tuplet (handles nesting)
                  num = cr.duration.numerator;
                  den = cr.duration.denominator;
                  var t = cr.tuplet;
                  while (t) {
                        num *= t.normalNotes;
                        den *= t.actualNotes;
                        t = t.tuplet;
                  }
            }

            console.log("TimeToTempo: tick " + cr.parent.tick + " written=" + cr.duration.numerator + "/" + cr.duration.denominator + " actual=" + num + "/" + den + (cr.tuplet ? " (in tuplet)" : ""));
            return Math.round((num / den) * 4 * ticksPerQuarter());
      }

      // Returns every selected note/chord/rest as {cr, track, tick, ticks}, sorted by start tick.
      // A chord with several selected noteheads is only counted once.
      function collectSelectedChordRests() {
            var result = [];
            var seen = {};
            var els = curScore.selection.elements;

            for (var i = 0; i < els.length; i++) {
                  var cr = toChordRest(els[i]);
                  if (cr == null) continue;

                  // Skip grace notes (their parent is a chord, not a segment)
                  var seg = cr.parent;
                  if (seg == null || seg.type !== Element.SEGMENT) continue;

                  var key = cr.track + ":" + seg.tick;
                  if (seen[key]) continue;
                  seen[key] = true;

                  result.push({ cr: cr, track: cr.track, tick: seg.tick, ticks: getChordRestTicks(cr) });
            }

            result.sort(function(a, b) { return a.tick - b.tick; });
            return result;
      }

      // Total time covered by the items in ticks. Overlaps (chords in other voices/staves
      // at the same moment) are only counted once; gaps between items are not counted.
      function totalTicksOf(items) {
            if (items.length == 0) return 0;

            var total = 0;
            var curStart = items[0].tick;
            var curEnd = items[0].tick + items[0].ticks;

            for (var i = 1; i < items.length; i++) {
                  var s = items[i].tick;
                  var e = s + items[i].ticks;
                  if (s <= curEnd) {
                        if (e > curEnd) curEnd = e;
                  } else {
                        total += curEnd - curStart;
                        curStart = s;
                        curEnd = e;
                  }
            }
            return total + (curEnd - curStart);
      }

      function calculateTempo() {

            // Get all currently selected notes / rests
            var items = collectSelectedChordRests();

            if (items.length == 0) {
                  showMessage("Warning", "Please select one or more notes or rests...");
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
                        showMessage("Error", msg);
                        return;
                  }

                  // Check if the starting and ending time are the same
                  if (startTime == endTime) {
                        showMessage("Error", "Start time and end time are the same...");
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
                  // Parse duration values and check if they are correctly formatted
                  durationTimeValues = parseTimeToArray(durationTimeInput.text);
                  if (durationTimeValues.length == 0) {
                        return;
                  }
            }

            // Total length of everything selected, measured in quarter notes
            var totalTicks = totalTicksOf(items);
            var quarterNotes = totalTicks / ticksPerQuarter();

            var durationInMilliseconds = calculateMilliseconds(durationTimeValues);

            if (quarterNotes <= 0) {
                  showMessage("Error", "The selection has no length...");
                  return;
            }
            if (durationInMilliseconds <= 0) {
                  showMessage("Error", "The duration must be longer than zero...");
                  return;
            }

            // BPM (in quarter notes per minute) = quarter notes / minutes
            var bpm = quarterNotes * 60000 / durationInMilliseconds;

            // Round the bpm to an integer or 2 d.p.
            bpm = (setInteger.checked) ? Math.round(bpm) : bpm.toFixed(2);

            // Create a new TEMPO_TEXT and apply the BPM
            applyTempo(bpm, items);
      }

      // bpm = quarter notes per minute, items = the selection the tempo was calculated from
      function applyTempo(bpm, items) {
            // The tempo goes on the first selected note/rest
            var first = items[0];

            // Make a new cursor to manipulate
            var cursor = curScore.newCursor();
            cursor.rewindToTick(0);
            cursor.track = first.track;
            cursor.rewindToTick(first.tick);

            curScore.startCmd();

            // Create a new TEMPO_TEXT element
            var tempoElement = newElement(Element.TEMPO_TEXT);

            // Set text
            tempoElement.text = '\uECA5' + ' = ' + bpm;
            tempoElement.visible = true;

            // Add the element to the score
            cursor.add(tempoElement);

            // This has to be done after the element is added to the score for some reason
            tempoElement.tempo = parseFloat(bpm) / 60;
            tempoElement.tempoFollowText = true;

            // End the command
            curScore.endCmd();

            // Set the ending time as the new starting time
            startingTimeValue.text = endingTimeValue.text;
            endingTimeValue.text = "";
            durationTimeInput.text = "";

            // Go to the note after the selection
            selectAdjacent(true, items);
      }



      function parseTimeToArray(timeString) {
            // Split the time string at ':' and '.'
            var timeParts = timeString.split(/[:.]/);
            
            // Make sure that there are only 4 parts
            if (timeParts.length !== 4) {
                  showMessage("Error", "Invalid time format. Expected HH:MM:SS.FFF");
                  return [];
            }
            
            // Regex for the digits 0-9
            var numberRegex = /^[0-9]+$/;
            
            try {
                  // Make sure that only digits are present otherwise spit out an error
                  for (var i = 0; i < timeParts.length; i++) {
                        if (!numberRegex.test(timeParts[i])) {
                              showMessage("Error", "Invalid characters in time input...");
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
                  showMessage("Error", "Error parsing time...");
                  return [];
            } 
      }

      function calculateDuration(startValues, endValues) {
            // Calculate the duration in milliseconds
            var durationMilliseconds = calculateMilliseconds(endValues) - calculateMilliseconds(startValues);

            // Make sure duration is a positive time span
            if (durationMilliseconds < 0) {
                  showMessage("Error", "End time is earlier than start time...");
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
      
      // Select the note/rest before the selection (next = false) or after it (next = true)
      function selectAdjacent(next, items) {
            if (items === undefined) items = collectSelectedChordRests();
            if (items.length == 0) return;

            // Reference = earliest item going backwards, item that ends last going forwards
            var ref = items[0];
            if (next) {
                  for (var i = 1; i < items.length; i++) {
                        if (items[i].tick + items[i].ticks >= ref.tick + ref.ticks) ref = items[i];
                  }
            }

            var c = curScore.newCursor();
            c.rewindToTick(0);
            c.track = ref.track;
            c.rewindToTick(ref.tick);

            var moved = next ? c.next() : c.prev();
            if (!moved || c.element == null) return;

            // select the new element
            curScore.selection.select(getSelectableElement(c.element));
      }

      // FOR ABOVE CODE: CREDIT GOES TO "xiaomigros" (discord) FOR THIS CODE
      //====================================================================
      
      // GUI
      Rectangle {
            id: ctrlRectangle
            
            property alias msgDiag: msgDiag
            property alias pluginGUI: pluginGUI
            property alias startingTimeValue: startingTimeValue
            property alias endingTimeValue: endingTimeValue
            property alias durationTimeInput: durationTimeInput
            property alias setInteger: setInteger
            property alias calculateButton: calculateButton
            property alias rewindBtn: rewindBtn
            property alias skipBtn: skipBtn

            width: 360
            height: 240
            color: "#e6ebe0"

            // Error handling popup template
            MessageDialog  {
                  id: msgDiag
                  title: "Title"
                  text: "Text"
                  visible: false
                  onAccepted: {
				//msgDiag.visible = false;
                        msgDiag.close();
			}
            }

            // The grid layout for items
            GridLayout {
                  id: pluginGUI
                  anchors.fill: parent
                  anchors.margins: 10
                  columns: 3
                  focus: true

                  // Starting time
                  Label { 
                        text: "Starting time:"
                        font.pixelSize: 18      
                        font.bold: true
                        color: "#ED6A5A"
                        
                        MouseArea{
                              anchors.fill: parent
                              onClicked:  {
                                    startingTimeValue.text = "";
                                    startingTimeValue.paste();
                              }
                        }
                  }
                  TextField {
                        id: startingTimeValue
                        Layout.columnSpan: 2
                        placeholderText: "<font color=\"#7F7F7F\">HH:MM:SS.FFF</font>"
                        font.pixelSize: 12
                        font.bold: true

                        background: Rectangle {
                              y: 1
                              radius: 4
                              implicitWidth: 140
                              implicitHeight: 24
                              border.color: "#5CA4A9"
                              border.width: 2
                        }

                        Component.onCompleted: {
                              startingTimeValue.color = "#7F7F7F";
                        }
                  }

                  // Ending time
                  Label {
                        text: "Ending time:"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#ED6A5A"
                        
                        MouseArea{
                              anchors.fill: parent
                              onClicked:  {
                                    endingTimeValue.text = "";
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
                        placeholderText: "<font color=\"#7F7F7F\">HH:MM:SS.FFF</font>"
                        font.pixelSize: 12
                        font.bold: true

                        background: Rectangle {
                              y: 1
                              radius: 4
                              implicitWidth: 140
                              implicitHeight: 24
                              border.color: "#5CA4A9"
                              border.width: 2
                        }

                        Component.onCompleted: {
                              endingTimeValue.color = "#7F7F7F";
                        }
                  }

                  // Duration time
                  Label {
                        text: "Duration time:"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#ED6A5A"
                        
                        MouseArea{
                              anchors.fill: parent
                              onClicked:  {
                                    durationTimeInput.text = "";
                                    durationTimeInput.paste();
                                    calculateTempo();
                              }
                        }
                  }
                  TextField {
                        id: durationTimeInput
                        Layout.columnSpan: 2
                        placeholderText: "<font color=\"#7F7F7F\">HH:MM:SS.FFF</font>"
                        font.pixelSize: 12
                        font.bold: true

                        background: Rectangle {
                              y: 1
                              radius: 4
                              implicitWidth: 140
                              implicitHeight: 24
                              border.color: "#5CA4A9"
                              border.width: 2
                        }

                        Component.onCompleted: {
                              durationTimeInput.color = "#7F7F7F";
                        }
                  }
            
                  // Integer BPM
                  Label {
                        text: "Set as integer:"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#ED6A5A"
                  }
                  CheckBox {
                        id: setInteger
                        
                        indicator: Rectangle {
                              y: 8
                              implicitWidth: 16
                              implicitHeight: 16
                              radius: 4
                              border.color: "#5CA4A9"
                              border.width: 2
                              
                              Rectangle {
                                    visible: setInteger.checked
                                    color: "#ED6A5A"
                                    radius: 2
                                    anchors.margins: 4
                                    anchors.fill: parent
                              }
                        }
                  }
            
                  // Calculate
                  Button {
                        id: calculateButton
                        Layout.columnSpan: 3

                        contentItem: Text {
                              text: "Calculate"
                              font.pixelSize: 14
                              font.bold: true
                              color: "#F4F1BB"
                              horizontalAlignment: Text.AlignHCenter
                              verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                              x: 20
                              implicitWidth: 251
                              implicitHeight: 30
                              color: "#5CA4A9"
                              radius: 4
                              border.color: "#F4F1BB"
                              border.width: 2
                        }

                        Component.onCompleted: {
                              calculateButton.contentItem.x = 24;
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

                        contentItem: Text {
                              text: "Previous note"
                              font.pixelSize: 12
                              font.bold: true
                              color: "#F4F1BB"
                              horizontalAlignment: Text.AlignHCenter
                              verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                              x: 20
                              implicitWidth: 100
                              implicitHeight: 30
                              color: "#5CA4A9"
                              radius: 4
                              border.color: "#F4F1BB"
                              border.width: 2
                        }

                        Component.onCompleted: {
                              rewindBtn.contentItem.x = 24;
                        }
                        
                        onClicked: {
                              // Rewind and select the previous note
                              curScore.startCmd();
                              selectAdjacent(false);
                              curScore.endCmd();
                        }
                  }
            
                  // Next note
                  Button {
                        id: skipBtn
                        Layout.columnSpan: 1

                        contentItem: Text {
                              text: "Next note"
                              font.pixelSize: 12
                              font.bold: true
                              color: "#F4F1BB"
                              horizontalAlignment: Text.AlignHCenter
                              verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                              x: 20
                              implicitWidth: 100
                              implicitHeight: 30
                              color: "#5CA4A9"
                              radius: 4
                              border.color: "#F4F1BB"
                              border.width: 2
                        }

                        Component.onCompleted: {
                              skipBtn.contentItem.x = 24;
                        }
                        
                        onClicked: {
                              // Skip and select the next note
                              curScore.startCmd();
                              selectAdjacent(true);
                              curScore.endCmd();
                        }
                  }

            }

      }

      //Show the message dialogue with the desired title, text and icon
      function showMessage(title, text) {
            msgDiag.title = title;
            msgDiag.text = text;
            
            msgDiag.visible = true;
      }
}