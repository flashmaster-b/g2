/** Sensuino2 Class reads Bytes from Serial port and converts it to float values
 * Construct by passing a String Array of which data points to read
 * sensuino will attempt to read the values from serial (4 bytes each)
 * and convert them to float values.
 * Update values by passing Serial interface from interrupt
 *
 */
  
class Sensuino2 {
  String date;
  FloatDict val;
  FloatDict max;
  FloatDict min;
  final byte[] bytes = new byte[Float.BYTES];        // Byte Array for reading from serial (contains one float value)
  final FloatBuffer buf = ByteBuffer.wrap(bytes).order(java.nio.ByteOrder.BIG_ENDIAN).asFloatBuffer();

  Sensuino2(String[] values) {
    val = new FloatDict();
    min = new FloatDict();
    max = new FloatDict();
    for(int i=0; i<values.length; i++) {
      val.set(values[i], 0.0);
      min.set(values[i],MAX_FLOAT);
      max.set(values[i],MIN_FLOAT);
    }
  }
  
  
  /** 
   * update current values with data from serial. Will be called by serial interrupt 
   * @param serial the serial port to read from 
   */
  void update(Serial serial) {
    boolean fail = false;
    for(String k : val.keyArray()) {
      serial.readBytes(bytes);
      if(!Float.isNaN(buf.get(0))) {
        val.set(k,buf.get(0));
        if(val.get(k) < min.get(k)) min.set(k,val.get(k));
        if(val.get(k) > max.get(k)) max.set(k,val.get(k));
      } else { 
        print(k + " ");
        fail = true;
      }
    }
    if(fail) println(": NaN detected! "+int(random(1024)));
  }

   
  float getValue(String k) {
    return(val.get(k));
  }
  
  float getMin(String k) {
      return(min.get(k));
  }
  
  float getMax(String k) {
      return(max.get(k));
  }
  
  // returns a human readable string of all values
  String getValueString() {  
    String all = new String();
    for(String k : val.keyArray()) {
      all += k + ": " + String.format("%04.2f",val.get(k)) + ", ";
    }
    return all;
  }
}
