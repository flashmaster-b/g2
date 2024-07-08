/** All pre set values for G2 are set here */


// Folder that contains samples for grain analysis
// only wav or aif files will work
// con also be selected on runtime but this one will be used if set

public static String FOLDER = "";


// if working continuously on one composition, it can be loaded automatically on startup
// by setting this

public static String LOAD_ON_START = "/home/juergen/Desktop/old/g2/data/YCTRUHGT.json";


// Sensor values sent via serial port
// the values will be interpreted as float values  
// sent as bytes over serial port
// only the first eight can be mapped via MIDI console

public static String[] SENSOR_INPUTS = {
  "d1",
  "d2",
  "d3",
  "eCO2",
  "PM25",
  "PM10",
  "bright",
  "temp",
  "hg"
};


// Mapping outputs. These are the parameters that can be modulated by the sensor readings

public static String[] MAPPING_OUTPUTS = {
  "volume",
  "cutoff",
  "pitch"
};


// default min max values for mapping outputs (has to be same length and order than MAPPING_OUTPUTS!)

public static float[] MAPPING_OUT_MAX = {
  1.0,
  10000.0,
  10.0
};

public static float[] MAPPING_OUT_MIN = {
  0.0,
  20.0,
  0.1
};


// step values for pitch and frequency

public static float minpitchStep = 0.05;
public static float minFreqStep = 1;


// BPM for sequencer

public static int BPM = 96;

/** 
 * set this to  save all data points to a JSON file
 */
public static boolean SAVE_DATA = true;

/** 
 * how often to write data to disk (all n serial  interrupts (one should be 250 ms?))
 */
public static int SAVE_FREQ = 40;  // all 10 seconds

/** how many grains to display per row */
public static int ROWS = 5;
