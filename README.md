# ⏱️ TimeToTempo  

*A MuseScore plugin to convert a given time frame into a tempo.*  

> **Note:** This plugin currently supports **MuseScore 3** only.

---

## 🚀 Features  

- Converts a **time duration** into an appropriate **tempo marking**.  
- Added a **duration-based calculation option**, allowing tempo to be determined from a single duration instead of start and end times.  
- **Clipboard integration**: Clicking text labels next to input fields will paste clipboard contents.  
  - The plugin will **automatically calculate a tempo** when clicking:  
    - **Ending Time** *(if "Starting Time" is filled in)*  
    - **Duration Time**  
- Option to **limit tempo to integers** or allow values **up to two decimal places**.  
- **Navigate the score** using the **Previous Note** and **Next Note** buttons.  

---

## 🎵 How to Use  

1. **Open a score** in **MuseScore 3**.  
2. **Select a note or rest** before performing calculations.  
3. Enter a **starting time** in the format: `HH:MM:SS.FFF`  
4. Toggle the **integer option** to round the tempo to a whole number *(if desired)*.  
5. Click **Calculate** to determine the tempo.  
6. Use **Previous Note** and **Next Note** buttons to navigate within the selected stave.  
7. **Clipboard shortcuts**:  
   - Click on the **text label** of any input field to **paste clipboard contents** into it.  
   - Clicking **"Ending Time"** or **"Duration Time"** will **auto-calculate the tempo**, if possible.  

---

## ⚠️ Known Issues
- When using the **Previous** and **Next** buttons to go to a different note/rest. The visual indicator showing which note/rest is selected disappears.
  - This does not happen when the **Calculate** button is pressed (I don't know why this happens in the first place)

---

## 📌 To-Do List  

- [x] Add duration time option
- [ ] Make window always stay on top
- [ ] Possibly add tempo per beat support
- [x] Implement MuseScore 4 support

---

i used ai to make this READ.ME so beware its a bit sh*tty at the moment... i will actually make a good one myself sometime soon (maybe)...
