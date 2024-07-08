/**
 * <h1>g2</h1>
 * <h2>Grain Synthesizer for 'Rikitu' Epizoon</h2>
 *
 * g2 is a grain synthesizer developed for an interactive artwork.
 * It reads audio samples from a folder and creates various audio grains
 * in multiple layers, the behaviour of which can be controlled by 
 * environmental values that get sent via Serial port. Grains and compositions
 * can be stored in JSON-Files or new compositions can be created in a 
 * graphic interface via mouse/keyboard and a midi controller (for now, only 
 * APC Key 25 is supported).
 * 
 * @author Jürgen Buchinger <hi@differentspace.com>
 * @version 3.11 Jul 2024 
 *
 */
 

import processing.serial.*;
import themidibus.*;
import processing.sound.*;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;


/** All the grains are stored in this list */
ArrayList<Grain> g;

/** the currently selected layer i.e. the currently selected grain */
int layer=0;

/** The Sensuino class manages communication via Serial port */
Sensuino2 sens;

/** The serial connection */
Serial serial;

/** All the mappings are stored in this list */
ArrayList<Mapping> mapping = new ArrayList<Mapping>();

/** 
 * The min/max values for mapping out, that is, the min and max values
 * a control can have, f.i. 20 - 10000 Hz for cutoff frequency, can be set
 * in settings.
 */
FloatDict mappingOutMax, mappingOutMin;

/**
 * The inputs and outputs for mapping are stored here. Inputs are measurements 
 * from sensor such as co2 concentration, outputs are controls such as cutoff frequency.
 * Have to be set in settings and correspond to what is sent via Serial.
 */
String mappingIn="", mappingOut="";

/** All sensor readings and mapping controls in one string. Used for display. */
String sensorReadingsString, mappingOutputString;

/** All audiosamples in the samples folder are stored here */
ArrayList<String> audioSamples = new ArrayList<String>();

float[] sub;

/** flags for different modes, they affect what is drawn and what different keys/midi controls do */
boolean editMode = false, rec=false, loading=false, plus10=false, map=false, mute=false, serial_on=false, 
  dataControl=false, stop=false, mappingGlide = false, showMappings = false, updateData = false, 
  display=true, midi_on=false;

/** saves the last time a message was received via serial port */
long lastMillis;

/** this variable is used to store the on/off values of grains when muting all but one or when synchronizing sequenced grains */
boolean[] editOn = new boolean[16];

/** the midi connection */
MidiBus apc;

/** auxiliary variable for mapping preview */
int currentMapping = -1;

/** single unique identifier of the epizoon that makes this noise, is global for saving and resaving purposes */
String DNA = "";

/** variable to store data points for saving to disk */
JSONArray allData;

/** number of sensor updates (used for saving) */
int updates;

/** the filename for saving data */
String allDataFile;


void setup() {
  fullScreen();
  colorMode(HSB,360,100,100);
  background(0);
  PFont mono = createFont("monotalic.otf", 18);
  allData = new JSONArray();
  allDataFile = nf(year(),4)+"-"+nf(month(),2)+"-"+nf(day(),2)+"T"+nf(hour(),2)+"."+nf(minute(),2)+"."+nf(second(),2);
  
  g = new ArrayList<Grain>();
  // if you want to print all available serial ports to console, uncomment next line
  // printArray(Serial.list());
  String portName = Serial.list()[1];
  try {
    println("Opening sens");
    sens = new Sensuino2(SENSOR_INPUTS);
    println("Opening Serial");
    serial = new Serial(this, portName, 9600);
    serial.buffer(Float.BYTES*SENSOR_INPUTS.length);
    serial_on = true;
  } catch (RuntimeException e) {
    println("Serial port not found or busy, skipping");
    serial_on = false;
  }
  textFont(mono);
  // MidiBus.list();
  try {
    apc = new MidiBus(this, 1, 2);
    midi_on = true;
  } catch(NullPointerException e) {
    println("Midi device not found, disabling midi");
    midi_on=false;
  }
  if(midi_on) setLaunchLights();
  sensorReadingsString = new String();
  mappingOutMax = new FloatDict();
  mappingOutMin = new FloatDict();
  mappingOutputString = new String();
  for(int i=0; i<MAPPING_OUTPUTS.length; i++) {
    mappingOutputString+=MAPPING_OUTPUTS[i]+"  ";  
    mappingOutMax.set(MAPPING_OUTPUTS[i],MAPPING_OUT_MAX[i]);
    mappingOutMin.set(MAPPING_OUTPUTS[i],MAPPING_OUT_MIN[i]);
  }
  for(int i=0; i<SENSOR_INPUTS.length; i++) sensorReadingsString+=SENSOR_INPUTS[i]+"  ";
  if(LOAD_ON_START != "") {
    File f = new File(LOAD_ON_START);
    loadG2(f);
  }
  if(FOLDER != "") {
    File f = new File(FOLDER);
    loadSamples(f);
  }
  if(serial_on) {
    print("Starting Data Updates. ");
    serial.clear();    // clear serial buffer and write one byte to start arduino
    updateData = true;
    print("Waiting... ");
    delay(1000);
    serial.write(65);
    delay(1000);
    println("byte sent. ");
    dataControl = true;
    println("data control on");
  }
  noLoop();
}

void draw() {
  if(display) {
    background(0);
    if(FOLDER == "") estart();
    // ====================================================================== draw waveforms and status =====
    if(loading) {
      g.get(layer).draw(15,45,width-15,height);
      fill(g.get(layer).c);
      text("grain"+layer+": file="+g.get(layer).filename+", pos="+g.get(layer).position+", dur="+g.get(layer).duration,5,20);
      if(mappingIn == "") text("Mapping: "+sensorReadingsString,5,55);
      else text("Mapping: "+mappingIn+" ("+sens.getMin(mappingIn)+"/"+sens.getMax(mappingIn)+")",5,55);
      if(mappingOut == "") text("To:      "+mappingOutputString,5,80);
      else text("To:      "+mappingOut+ "("+mapping.get(currentMapping).min+"/"+mapping.get(currentMapping).max+")",5,80);
      text("Values:  cutoff="+g.get(layer).cutoff + "  pitch="+g.get(layer).pitch+"  reverb="+g.get(layer).revRoom+"/"+g.get(layer).revDamp+"/"+g.get(layer).revWet,5,105);     
      String mapText = "";
      for(Mapping m : mapping) {
        if(m.id == layer) {
          mapText += m.in + " to " + m.out + " (" + m.min + " < " + m.max + ")\n";
        }
      }
      text(mapText,width/2,20);
    } else {
      float y = 45;
      int t=0;
      for(int i=0; i<g.size(); i++) {
        if(g.get(i).running) {
          t=i;
          if(i>=ROWS) {
            y = 350;
            t = i-ROWS;
          }
          float x = 15+(t*(width-30)/ROWS);
          g.get(i).draw(x,y,(width-30)/ROWS-10,125);
          fill(g.get(i).c);
          text("grain"+i,x,y-20);
        }
      }
      fill(255);
      if(plus10) text("p",width-15,height-45);
      if(editMode) {
        noFill();
        stroke(255);
        if(layer < ROWS) {
          rect(ROWS+(layer*(width-30)/ROWS),10,55,20);
        } else {
          rect(13+((layer-ROWS)*(width-30)/ROWS),215,55,20);
        }        
      }
    }  
    if(serial_on) {
      fill(255);
      textSize(16);
      text(sens.getValueString(),15,height-45);
      textSize(18);
    }
    if(showMappings) {
      text(allMappings(), width/2, height/2);
    }
    if(rec) saveFrame("rec/g2-#####.png");
  }
}

void mousePressed() {
  if(loading && editMode && !g.get(layer).setting) {
    float dur = map(mouseY,0,height,0.001,0.2);
    float pos = map(mouseX,0,width,0,g.get(layer).f.duration()-dur);
    try {
      if(g.get(layer).sequenced) g.get(layer).set(pos,dur,BPM);
      else g.get(layer).set(pos,dur);
      g.get(layer).start();
    } catch (Exception e) {
      println("ERROR: "+e);
    }
  }
  redraw();
}

void keyPressed() {
  if(key == 'r') {
    if(rec) rec=false;
    else rec=true;
  } else if(key >= 48 && key <= 57) {
    int k = key-48;
    if(plus10) k+=10;
    if(g.size() > k) {
      layer=k;
      if(!editMode) {
        if(g.get(layer).running) {
          g.get(layer).stop();
        } else {
          g.get(layer).start();
        }
      }
    }
  } else if(key == 's') {
    save();
  } else if(key == 'e') {
    if(editMode) editMode = false;
    else editMode = true;
  } else if(key == 'm') {
    toggleMute();
  } else if(key=='d' && editMode) {
    g.get(layer).setReverb(0.7,0.2,0.7);    
  } else if(key=='l') {
    if(loading) {
      loading=false;
      setLaunchLights();
    } else {
      loading=true;
      setLaunchLights();
    }
  } else if(key=='a') {
    layer=g.size();
    g.add(new Grain(this));
    loadGrain(audioSamples.get(int(random(audioSamples.size()))));
  } else if(key=='p') {
    if(plus10) plus10 = false;
    else plus10 = true;
  } else if(key=='q') {
    serial.write(50);
  } else if(key=='c') {
    if(dataControl) dataControl = false;
    else dataControl = true;
  } else if(key=='o') {
    selectInput("select G2", "loadG2");
  } else if(key=='n') {
    if(FOLDER == "") {
      selectFolder("Choose Folder for Samples", "loadSamples");
    }
  } else if(key=='t') {
    Sound.list();
  } else if(key == '.') {
    if(display) display = false;
    else display = true;
  } else if(key == '-') {
    if(showMappings) showMappings = false;
    else showMappings = true;
  } else if(key == CODED) {
    if(keyCode == UP && editMode) {
      g.get(layer).setCutoff(g.get(layer).cutoff+=10);
      g.get(layer).cutoffTarget = g.get(layer).cutoff;
    } else if(keyCode == DOWN && editMode) {
      g.get(layer).setCutoff(g.get(layer).cutoff-=10);
      g.get(layer).cutoffTarget = g.get(layer).cutoff;
    } 
  }
  redraw();
}

/**
 * saves the current composition to JSON file
 */
void save() {
  JSONArray grains = new JSONArray();
  for (int i = 0; i < g.size(); i++) {
    JSONObject grain = new JSONObject();
    grain.setInt("id", i);
    grain.setFloat("pos", g.get(i).position);
    grain.setFloat("dur", g.get(i).duration);
    grain.setString("file", g.get(i).filename);
    grain.setFloat("amp", g.get(i).amp);
    grain.setFloat("pitch", g.get(i).pitch);
    grain.setFloat("cutoff", g.get(i).cutoff);
    grain.setBoolean("reverb", g.get(i).reverb);
    grain.setBoolean("on", g.get(i).running);
    grain.setBoolean("sequenced", g.get(i).sequenced);
    if(g.get(i).sequenced) {
      JSONArray sequence = new JSONArray();
      for(boolean b : g.get(i).sequence) {
        sequence.append(b);
      }
      grain.setJSONArray("sequence", sequence);
    }
    grains.setJSONObject(i, grain);
  }
  JSONArray modulations = new JSONArray();
  for(Mapping m : mapping) {
    JSONObject mod = new JSONObject();
    mod.setInt("id",m.id);
    mod.setString("in",m.in);
    mod.setString("out",m.out);
    mod.setFloat("max",m.max);
    mod.setFloat("min",m.min);
    mod.setBoolean("gliding",m.gliding);
    mod.setBoolean("fixedInLimits",m.fixedInLimits);
    if(m.fixedInLimits) {
      mod.setFloat("inMin",m.inMin);
      mod.setFloat("inMax",m.inMax);
    }
    modulations.append(mod);
  }
  JSONObject all = new JSONObject();
  all.setJSONArray("grains",grains);
  all.setJSONArray("modulations",modulations);
  all.setString("folder",FOLDER);
  if(DNA == "") {
    char[] n = new char[8];
    for(int i=0; i<8; i++) {
      n[i] = char(int(random(26)+65));
    }
    DNA = new String(n);
  }
  saveJSONObject(all, "data/"+DNA+".json");
  println("Saved "+DNA);
}

/**
 * loads audio samples from folder, filetypes can be AIFF and WAV, must be mono-Files
 * @param folder The folder to load samples from
 */
void loadSamples(File folder) {
  FOLDER = folder.getAbsolutePath()+"/";
  println("FOLDER: "+FOLDER);
  File f = new File(FOLDER);
  String[] dir = f.list(); 
  for(int i=0; i<dir.length; i++) {
    if(dir[i].substring(dir[i].length()-3).equals("wav") || dir[i].substring(dir[i].length()-3).equals("aif")) {
      audioSamples.add(dir[i]);
    }
  }
  print("SAMPLES:");
  printArray(audioSamples);
  redraw();
}

/**
 * loads a composition from a JSON-File 
 * @param g2file The file to load from
 */
void loadG2(File g2file) {
  if (g2file == null) {
    println("No file selected!");
  } else {
    String filename = g2file.getAbsolutePath();
    DNA = filename.substring(filename.length()-13,filename.length()-5);
    println("Loading samples from "+DNA);
    JSONObject g2 = loadJSONObject(filename);
    loadSamples(new File(g2.getString("folder")));
    JSONArray grains = g2.getJSONArray("grains");
    for(int i=0; i<grains.size(); i++) {
      JSONObject grain = grains.getJSONObject(i);
      float dur = grain.getFloat("dur");
      float pos = grain.getFloat("pos");
      g.add(new Grain(this));
      g.get(i).load(grain.getString("file"));
      if(grain.getBoolean("sequenced")) {
        for(int n=0; n<8; n++) {
          g.get(i).sequence[n] = grain.getJSONArray("sequence").getBoolean(n);
        }
        g.get(i).set(pos,dur,BPM);
      } else {
        g.get(i).set(pos,dur);
      }
      g.get(i).setAmp(grain.getFloat("amp"));
      g.get(i).setPitch(grain.getFloat("pitch"));
      g.get(i).setCutoff(grain.getFloat("cutoff"));
      if(grain.getBoolean("reverb")) {
        g.get(layer).rev.process(g.get(layer).as);
        g.get(layer).rev.set(0.7,0.2,0.7);
      }
      if(grain.getBoolean("on")) {
        g.get(i).start();
        if(i < 8) {
          apc.sendNoteOn(0,i+32,127);          
        } else {
          apc.sendNoteOn(0,i+16,127);    
        }
      }     
    }
    print("...loaded "+g.size()+" grains and ");
    JSONArray modulations = g2.getJSONArray("modulations");
    for(int i=0; i<modulations.size(); i++) {
      JSONObject m = modulations.getJSONObject(i);
      if(m.getBoolean("fixedInLimits")) {
        mapping.add(new Mapping(m.getInt("id"),m.getString("in"),m.getString("out"),m.getFloat("min"),m.getFloat("max"),m.getBoolean("gliding"),m.getFloat("inMin"),m.getFloat("inMax")));
      } else {        
        mapping.add(new Mapping(m.getInt("id"),m.getString("in"),m.getString("out"),m.getFloat("min"),m.getFloat("max"),m.getBoolean("gliding")));
      }
    }
    println(mapping.size()+" mappings from "+filename);
  }
  redraw();
}

/**
 * mutes all layers, or, if in edit-Mode, all but the selected layer
 */
void toggleMute() {
  if(editMode) {
    if(mute) {
      for(int i=0; i<g.size(); i++) {
        if(editOn[i]) g.get(i).start();
      }
      mute=false;
    } else {
      for(int i=0; i<g.size(); i++) {
        editOn[i] = g.get(i).running;
        if(i!=layer) g.get(i).stop();
      }
      mute = true;
    }
  } else {
    if(!mute) {
      for(int i=0; i<g.size(); i++) {
        editOn[i] = g.get(i).running;
        g.get(i).stop();
      }
      mute=true;
    } else {
      for(int i=0; i<g.size(); i++) {
        if(editOn[i]) g.get(i).start();
      }
      mute = false;
    }
  }
  if(mute) apc.sendNoteOn(0,85,127);
  else apc.sendNoteOn(0,85,0);
}

/**
 * Sets the lights on APC Key 25 according to the state of g2
 */
void setLaunchLights() {
  /* [32] [33] [34] [35] [36] [37] [38] [39]   --> Samples
   * [24] [25] [26] [27] [28] [29] [30] [31]   --> Samples
   * [16] [17] [18] [19] [20] [21] [21] [23]   --> Sequence
   * [08] [09] [10] [11] [12] [13] [14] [15]   --> Mod in
   * [00] [01] [02] [03] [04] [05] [06] [07]   --> Mod out
   */
  for(int i=0; i<=127; i++) {                // turn all lights off
    apc.sendNoteOn(0,i,0);
  }
  if(editMode) apc.sendNoteOn(0,86,127);     // turn on select light
  if(dataControl) apc.sendNoteOn(0,70,127);  // turn on send light
  if(loading) {
    apc.sendNoteOn(0,71,127);               // turn on device = loading light    
    for(int i=0; i<audioSamples.size(); i++) {    // turn launch keys for samples on
      if(i < 8) {
        apc.sendNoteOn(0,i+32,127);          
      } else {
        apc.sendNoteOn(0,i+16,127);    
      }
    }
    
    if(g.get(layer).sequenced) {              // turn sequencer lights on
      apc.sendNoteOn(0,84,127);               // turn on sequencer light
      for(int i=0; i<g.get(layer).sequence.length; i++) {
        if(g.get(layer).sequence[i]) {
          apc.sendNoteOn(0,i+16,127);      // turn on sequence
        } else {
          apc.sendNoteOn(0,i+16,0);        // turn off sequence
        }
      }
    } else {
      apc.sendNoteOn(0,84,0);            // turn off sequencer light
    }
    for(int i=0; i<SENSOR_INPUTS.length; i++) {  // turn mapping input selection on
      apc.sendNoteOn(0,i+8,127);
    }
    for(int i=0; i<MAPPING_OUTPUTS.length; i++) {  // turn mapping output selection on
      apc.sendNoteOn(0,i+0,127);
    }
    if(mappingGlide) apc.sendNoteOn(0,68,127);
  } else {
    for(int i=0; i<g.size(); i++) {
      if(g.get(i).running) {
        if(i < 8) {
          apc.sendNoteOn(0,i+32,127);          
        } else {
          apc.sendNoteOn(0,i+16,127);    
        }
      }     
    }
  }
}

/**
 * Snchronizes the sequenced layers to the same beat
 */ 
void syncSequencedGrains() {
  for(int i=0; i<g.size(); i++) {
    editOn[i] = g.get(i).running;
    if(g.get(i).sequenced) g.get(i).stop();
  }
  for(int i=0; i<g.size(); i++) {
    if(editOn[i] && g.get(i).sequenced) g.get(i).start();
  }
}

/**
 * loads a grain from an audiofile, dur and pos is set globally
 * @param filename The filename of the audiofile
 */
void loadGrain(String filename) {
  println("LOADING GRAIN");
  g.get(layer).load(filename);
  float dur_ = random(0.001,0.2);
  float pos_ = random(0,g.get(layer).f.duration()-dur_);
  g.get(layer).set(pos_,dur_);   // start with random value
  g.get(layer).start();
  loading=true;
  setLaunchLights();
  println("gs: "+g.size()+" – running: "+g.get(g.size()-1).running);
}

/**
 * this gets called for every received midi note and acts accordingly
 * @param channel The midi channel
 * @param pitch The note pitch
 * @param velocity The note velocity
 */
void noteOn(int channel, int pitch, int velocity) {
  // println(channel +", "+pitch+", "+velocity);
  if(channel == 1) {                     // if note is coming from the keyboard, calculate frequency of note
    double f = Math.pow(2,(pitch-69f)/12f)*440f;
    float p = map((float)f,130.8128,523.2511,0,2);
    // Map to grain
    g.get(layer).setPitch(p);
  } else if(pitch <= 39) {                             // if note is coming from scene launch
    if(loading) { 
      if(pitch >= 24) {                                // load file or
        int k;
        if(pitch >= 32) k = pitch-32;
        else k = pitch-16;
        if(k < audioSamples.size()) {
          loadGrain(audioSamples.get(k));
        }
      } else if(pitch >= 16) {                         // set sequence or
        int k = pitch-16;
        if(g.get(layer).sequence[k]) g.get(layer).sequence[k] = false;
        else g.get(layer).sequence[k] = true;
        g.get(layer).sequence(BPM);
      } else {                                       // set mapping
        if(pitch >= 8) {                            // set mapping input
          if(pitch-8 < SENSOR_INPUTS.length) {
            mappingIn = SENSOR_INPUTS[pitch-8];
            println("Mapping "+mappingIn);
          }
        } else {                                    // set mapping output
          if(pitch < MAPPING_OUTPUTS.length) {
            mappingOut = MAPPING_OUTPUTS[pitch];
            println("to "+mappingOut);
          }
        }
        if(mappingIn != "" && mappingOut != "") {
          if(currentMapping != -1) {
            mapping.remove(currentMapping);
          }
          mapping.add(new Mapping(layer,mappingIn,mappingOut,mappingGlide));
          currentMapping = mapping.size()-1;
          println("mapping "+currentMapping);
        }
      }
    } else {                                           // if not loading, turn grains on or off
      int k = pitch - 32;
      if(k < 0) k+=16;
      if(g.size() > k) {
        layer = k;
        if(!editMode) {
          if(g.get(layer).running) {
            g.get(layer).stop();
          } else {
            g.get(layer).start();
          }
        }
      }
    }
  } else if(pitch == 69) {                            // "pan" -> save active mapping
    if(loading && currentMapping > -1) {
      currentMapping = -1;
      mappingIn = "";
      mappingOut = "";
    }
  } else if(pitch == 68) {
    if(loading && currentMapping > -1) {
      if(mappingGlide) mappingGlide = false;
      else mappingGlide = true;
      println("Maaping glide="+mappingGlide);
    }
  } else if(pitch == 70) {                            // send key = data control off / on
    if(dataControl) {
      dataControl = false;
    } else {
      serial.write(50);
      dataControl = true;
    }    
  } else if(pitch == 71) {                            // "Device" -> toggle loading mode
    if(loading) {
      loading=false;
      if(currentMapping != -1) {
        mapping.remove(currentMapping);
        println("currentmapping removed now mapping: "+mapping.size());
        currentMapping = -1;
        mappingIn = "";
        mappingOut = "";
      }
      if(g.get(layer).sequenced) syncSequencedGrains();     // synchronize all sequenced grains
    } else {
      loading=true;
    }   
  } else if(pitch == 81) {                            // "stop all clips"
    exit();    
  } else if(pitch == 84) {                            // "rec arm" toggle sequencer mode in loading screen
    if(loading) {
      if(g.get(layer).sequenced) {
        g.get(layer).sequenced=false;
        g.get(layer).reset();
      } else {
        g.get(layer).sequenced = true;  
        g.get(layer).reset();
      }
    }
  } else if(pitch == 85) {                            // mute
    toggleMute();
  } else if(pitch == 86) {                            // edit mode on (select key)
    if(editMode) {
      editMode = false;
      apc.sendNoteOn(channel,pitch,0);
    } else {
      editMode = true;
      apc.sendNoteOn(channel,pitch,127);
    }
  } else if(pitch == 64) {
    plus10=false;
    apc.sendNoteOn(channel,64,127);
    apc.sendNoteOn(channel,65,0);
  } else if(pitch == 65) {
    plus10=true;
    apc.sendNoteOn(channel,65,127);
    apc.sendNoteOn(channel,64,0);
  }
  setLaunchLights();
  redraw();
}

/**
 * This gets called for every received continuous controller change and acts accordingly
 * @param channel The midi channel
 * @param number The controller number
 * @param value The controller value
 */
void controllerChange(int channel, int number, int value) {
  int gr = number-48;
  if(loading) {
    if(gr == 0) {
      g.get(layer).setAmp(mapCubed(value,0,127,0,1));
    } else if(gr==1) {
      g.get(layer).setCutoff(mapCubed(value,0,127,20,20000));
    } else if(gr==2) {
      g.get(layer).setReverb(map(value,0,127,0,1),-1,-1);
    } else if(gr==3) {
      g.get(layer).setReverb(-1,map(value,0,127,0,1),-1);
    } else if(gr==4) {
      g.get(layer).setReverb(-1,-1,map(value,0,127,0,1));
    } else if(gr==5) {
      if(currentMapping != -1) {
        mapping.get(currentMapping).min = map(value,0,127,0,mappingOutMax.get(mappingOut));
      }
    } else if(gr==6) {
      if(currentMapping != -1) {
        mapping.get(currentMapping).max = map(value,0,127,0,mappingOutMax.get(mappingOut)*2);
      }
    }
  } else {
    if(plus10) gr+=8;
    if(gr < g.size()) {
      g.get(gr).setAmp(mapCubed(value,0,127,0,1));
    }
  }
  redraw();
}

/**
 * This gets called on every received serial message,
 * then reads the environmental values and maps the corresponding 
 * controls. 
 * @param serial The serial connection
 */
void serialEvent(Serial serial) {
  if(updateData) {
    sens.update(serial);
    updates++;
    if(SAVE_DATA) {
      saveData();
    }
    // here we read the sensor values and do the mapping
    if(dataControl) {  
      for(int i=0; i<mapping.size(); i++) {
        // println("Setting "+mapping.get(i).out+" with "+sens.getValue(mapping.get(i).in)+" (min: "+sens.getMin(mapping.get(i).in)+", max: "+sens.getMax(mapping.get(i).in)+"), to (min: "+mapping.get(i).min+", max:"+mapping.get(i).max+")");
        float inMin, inMax;
        if(mapping.get(i).fixedInLimits) {
          inMin = mapping.get(i).inMin;
          inMax = mapping.get(i).inMax;
        } else {
          inMin = sens.getMin(mapping.get(i).in);
          inMax = sens.getMax(mapping.get(i).in);
        }
        if(mapping.get(i).gliding) {
          g.get(mapping.get(i).id).setModTarget(
            mapping.get(i).out,
            mapSquared(
              sens.getValue(mapping.get(i).in),
              inMin,
              inMax,
              mapping.get(i).min,
              mapping.get(i).max
            )
          );
        } else {
          // println(mapping.get(i).out + " on " + mapping.get(i).id + " to " + mapping.get(i).in + " (" + sens.getValue(mapping.get(i).in) + ")");
          g.get(mapping.get(i).id).setMod(
            mapping.get(i).out,
            mapSquared(
              sens.getValue(mapping.get(i).in),
              inMin,
              inMax,
              mapping.get(i).min,
              mapping.get(i).max
            )
          );          
        }
      }
    }
  }
  // here, we continuously adjust control values to their target values for gliding
  for(int i=0; i<g.size(); i++) {
    if(g.get(i).amp < g.get(i).ampTarget) g.get(i).incAmp(minpitchStep);
    else if(g.get(i).amp > g.get(i).ampTarget) g.get(i).decAmp(minpitchStep);
    if(g.get(i).pitch < g.get(i).pitchTarget) g.get(i).incPitch(minpitchStep);
    else if(g.get(i).pitch > g.get(i).pitchTarget) g.get(i).decPitch(minpitchStep);
    if(g.get(i).cutoff < g.get(i).cutoffTarget) g.get(i).incCutoff(minFreqStep);
    if(g.get(i).cutoff > g.get(i).cutoffTarget) g.get(i).decCutoff(minFreqStep);
  }
  redraw();
}

/**
 * maps a value to a range exponentially (power of 2)
 * returns 1 if value is NaN
 * @param value The value to map
 * @param start1 The min value of the input 
 * @param stop1 The max value of the input
 * @param start2 The min value of the output
 * @param stop2 The max value of the output
 * @return The mapped value
 */
float mapSquared(float value, float start1, float stop1, float start2, float stop2) {
  if(!Float.isNaN(value) && value < MAX_FLOAT) {
    if(start1==stop1 || start2==stop2) {
      return start2;
    }
    float inT = map(value, start1, stop1, 0, 1);
    float outT = inT * inT;
    return map(outT, 0, 1, start2, stop2);
  } else {
    return 1;
  }
}

/**
 * maps a value to a range exponentially (power of 3)
 * returns 1 if value is NaN
 * @param value The value to map
 * @param start1 The min value of the input 
 * @param stop1 The max value of the input
 * @param start2 The min value of the output
 * @param stop2 The max value of the output
 * @return The mapped value
 */
float mapCubed(float value, float start1, float stop1, float start2, float stop2) {
  if(!Float.isNaN(value) && value < MAX_FLOAT) {
    if(start1==stop1 || start2==stop2) {
      return start2;
    }
    float inT = map(value, start1, stop1, 0, 1);
    float outT = inT * inT * inT;
    return map(outT, 0, 1, start2, stop2);
  } else {
    return 1;
  }
}

/**
 * displays a start screen if no initial composition is loaded
 */
void estart() {
  fill(330,100,100);
  String welcome = 
  "G2 – GRAIN SYNTHESIZER\n" +
  "CONTROLS\n" +
  "\n" +
  "r:     record\n" +
  "e:     toggle editMode\n" +
  "s:     save an image to a file\n" +
  "m:     mute all; in editMode mute all but selected grain\n" +
  "d:     turn on reverb for selected grain (only editMode)\n" +
  "l:     load Grain\n" +
  "a:     add Grain\n" +
  "p:     switch to second row of grains\n" +
  "q:     Write byte to Arduino\n" +
  "c:     toggle on data control\n" +
  "o:     load G2\n" +
  "t:     select output device\n" +
  ".:     toggle display\n" +
  "-:     show mappings\n" +
  "UP:    set cutoff up\n" +
  "DOWN:  set cutoff down\n" +
  "number keys:  turn grains on/off or select grains in editMode\n" +
  "\n" +
  "PRESS n for new set or o for opening existing set";
  text(welcome,15,25);
}

/**
 * returns a string of all current mappings
 * @return A string with all the current mappings
 */
String allMappings() {
  String allMappingsString = "";
  for(Mapping m : mapping) {
    allMappingsString += "G" + m.id + ": " +m.in + " to " + m.out + " (" + m.min + " < " + m.max + ")";
    if(m.gliding) allMappingsString += " (gliding)";
    allMappingsString += "\n";
  }
  return allMappingsString;
}

/**
 * saves environmental data to JSON file
 */
void saveData() {
  JSONObject js = new JSONObject();
  String date = nf(year(),4)+"-"+nf(month(),2)+"-"+nf(day(),2)+"T"+nf(hour(),2)+":"+nf(minute(),2)+":"+nf(second(),2);
  js.setString("date",date);
  for(String input : SENSOR_INPUTS) {
    js.setFloat(input,sens.getValue(input));
  }
  allData.setJSONObject(updates,js);
  if(updates%SAVE_FREQ == 0) {
    if(saveJSONArray(allData, "data/" + allDataFile + ".json")) {
    } else {
      println(updates+": saving failed!");
    }
  }
}

/**
 * restarts the serial connection. Will be called if g2 doesn't receive
 * data via Serial for some time. Should reset Arduino.
 */
 
void restartSerial() {
  serial.clear();
  serial.stop();
  String portName = Serial.list()[1];
  try {
    println("Re-opening Serial");
    serial = new Serial(this, portName, 9600);
    serial.buffer(Float.BYTES*SENSOR_INPUTS.length);
  } catch (RuntimeException e) {
    println("Serial port not found or busy!");
    serial_on = false;
  }
}
