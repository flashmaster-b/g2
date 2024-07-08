/**
 * Grain class for G2 synthesizer
 * each grain is an instance of this class
 * @version  2.8 26 Aug 2022
 * @author   Juergen Buchinger
 */
 
class Grain {
  AudioSample as;
  Reverb rev;
  Delay delay;
  LowPass lowpass;
  SoundFile f;
  boolean running = false, sequenced=false, setting=false, reverb=false;
  boolean[] sequence;
  float[] samples;
  float attackTime = 0.1; // attack and release time for grain envelope = crossfade time. Is factor of grain length
  float pitch = 1, pitchTarget = 1;
  float amp = 1, ampTarget = 1;
  float revRoom,revDamp,revWet=0;
  float cutoff = 20000, cutoffTarget=20000;
  color c;
  float position, duration; // this is public for saving
  PApplet p;
  String filename;      // name of the file without path, path is stored for all samples in FOLDER
  int bpm;
  
  Grain(PApplet p_) {
     p = p_;
     as = new AudioSample(p,1);        // create AudioSample with 1 frame
     rev = new Reverb(p);
     delay = new Delay(p);
     lowpass = new LowPass(p);
     samples = new float[1];
     sequence = new boolean[8];
     for(int i=0; i<sequence.length; i++) sequence[i] = false;
     int col = floor(random(300))-60;        // create a random color but not in the dark blue hues for visibility
     if(col<0) col+=360;
     c = color(col,100,100);
  }   
  
  void load(String filename_) {
    filename = filename_;
    println("Grain loading "+FOLDER+filename);
    f = new SoundFile(p,FOLDER+filename);
  }
  
  // remap grain to current sequence
  void sequence(int bpm_) {
    bpm = bpm_;
    set(position,duration,bpm);
    as.loop();
  }
  
  // remap grain without sequence
  void reset() {
    if(sequenced) {
      sequence(bpm);
    } else { 
      set(position,duration);
      as.loop();
    }
  }
  
  // create one grain from loaded audiofile MONO ONLY!
  void set(float position_, float duration_) {
    setting = true;
    position = position_;
    duration = duration_;
    // extract the datapoints for the grain using start position and duration
    f.cue(position);
    int start = f.positionFrame();
    f.cue(position+duration);
    int end = f.positionFrame();
    int len = end-start;
    samples = new float[len];
    // println("len="+len+", start="+start);
    f.read(start,samples,0,len);
    
    // build a crossfade into the grain 
    float attack = float(int(samples.length * attackTime + 1));
    float[] blend = new float[samples.length-int(attack)];
    for(int i=0; i<attack; i++) {
      blend[i] = samples[i]*((i+1.)/attack) + samples[samples.length-(int(attack)-i)]*((attack-(i+1))/attack);
    }
    for(int i=int(attack); i<blend.length; i++) {
      blend[i] = samples[i];
    }
    samples = blend;
    // resize AudioSample and load data points
    as.resize(samples.length);
    as.write(samples);
    lowpass = new LowPass(p);
    lowpass.process(as,cutoff);
    setAmp(amp);
    sequenced = false;
    setting = false;
  }
  
  // create one grain from loaded audiofile, this time with an on/off sequence instead of continuous looping
  // sequence will be taken from Grain, therefore has to be set before calling set
  void set(float position_, float duration_, int bpm_) {   
    setting = true;
    position = position_;
    duration = duration_;
    bpm = bpm_;
    
    // calculate length in samples for 8 beats
    int samplesPerBeat = int(44100.*60./(float(bpm)*2.));  // calculate samples per 1/8th note iin a 4/4 tact
    println(samplesPerBeat + " samples per beat");
    // extract the datapoints for the grain using start position and duration
    f.cue(position);
    int start = f.positionFrame();
    f.cue(position+duration);
    int end = f.positionFrame();
    int len = end-start;
    samples = new float[len];
    println("len="+len+", start="+start);
    f.read(start,samples,0,len);
    
    // build fade out and in into the grain 
    float attack = float(int(samples.length * attackTime + 1));
    float[] blend = new float[samplesPerBeat*8];
    for(int i=0; i<attack; i++) {
      samples[i] *= ((i+1.)/attack);
    }
    for(int i=0; i<attack; i++) {
      samples[samples.length-(int(attack)-i)] *= ((attack-(i+1))/attack);
    }
    
    // write sequenced grains into blend 
    for(int i=0; i<sequence.length; i++) {
      if(sequence[i]) {
        for(int t=0; t<samples.length; t++) {
          blend[i*samplesPerBeat+t] = samples[t];
        }
      }
    }
    samples = blend;
    
    // resize AudioSample and load data points
    as.resize(samples.length);
    as.write(samples);
    lowpass = new LowPass(p);
    lowpass.process(as,cutoff);
    setAmp(amp);
    sequenced = true;
    print("mapped with sequence: |");
    for(int i=0; i<sequence.length; i++) {
      if(sequence[i]) print("o");
      else print("_");
    }
    println("|");
    setting=false;
  }
  
  void setReverb(float room, float damp, float wet) {
    if(!reverb) reverb();
    if(room >=0) revRoom = room;
    if(damp >=0) revDamp = damp;
    if(wet >=0) revWet = wet;
    rev.set(revRoom, revDamp, revWet);
  }
  
  void reverb() {
    rev.process(as);
    reverb = true;
    lowpass.process(as);
  }
  
  void stop() {
    as.stop();
    running = false;
  }
  
  void start() {
    as.loop();
    lowpass.process(as,cutoff);
    running = true;
  }
  
  void setPitch(float pitch_) {
    if(pitch_ != pitch) {
      pitch = pitch_;
      pitchTarget = pitch;
      as.rate(pitch);
    }
  }
  
  void incPitch(float step) {
    as.rate(pitch+step);
    pitch += step;
  }

  void decPitch(float step) {
    if(pitch-step > 0) {
      as.rate(pitch-step);
      pitch -= step;
    }
  }

  void setAmp(float amp_) {
    if(amp_ <= 0.01) amp_=0.01;
    if(amp_ != amp) {
      amp = amp_;
      ampTarget = amp;
      as.amp(amp);
    }
  }
  
  void incAmp(float step) {
    if(amp+step <=1) {
      as.amp(amp+step);
      amp += step;
    }
  }
  
  void decAmp(float step) {
    if(amp-step >= 0.01) {
      as.amp(amp-step);
      amp -= step;
    }
  }
  
  void setCutoff(float cutoff_) {
    if(cutoff_ != cutoff) {
      cutoff = cutoff_;
      cutoffTarget=cutoff;
      lowpass.freq(cutoff);
    }
  }
  
  void incCutoff(float step) {
    cutoff+=step;
    lowpass.freq(cutoff);
  }
  
  void decCutoff(float step) {
    cutoff-=step;
    lowpass.freq(cutoff);
  }

  void incSamplesAmp(float amp) {
    for(int i=0; i<samples.length; i++) {
      samples[i] *= amp;
    }
    as.write(samples);
  }
  
  void setMod(String mod, float set) {
    if(mod.equals("cutoff")) {
      setCutoff(set);
    } else if (mod.equals("pitch")) {
      setPitch(set);
    } else if (mod.equals("volume")) {
      setAmp(set);
    } else {
      println(" mod not found");
    }
  }
  
  void setModTarget(String mod, float set) {
    if(mod.equals("cutoff")) {
      cutoffTarget = set;
    } else if (mod.equals("pitch")) {
      pitchTarget = set;
    } else if (mod.equals("volume")) {
      ampTarget = set;
    }
    // println("Set "+mod+" to: "+set);
  }
  
  void draw(float x_off, float y_off, float w, float h) {
    stroke(c);
    for(int i=0; i<samples.length-1; i++) {
      float x1 = x_off+map(i,0,samples.length,0,w);
      float x2 = x_off+map((i+1),0,samples.length,0,w);
      float y1 = y_off+map(samples[i],-.45,.45,0,h);
      float y2 = y_off+map(samples[i+1],-.45,.45,0,h);
      line(x1,y1,x2,y2);
    }
    float ampHeight = map(amp,0,1,0,h);
    noStroke();
    fill(c);
    y_off += h;
    rect(x_off,y_off+h-ampHeight,w/2,ampHeight);
    x_off += 3;
    stroke(c);
    line(x_off+w/2,y_off+2*h/3,x_off+w,y_off+2*h/3);
    noStroke();
    if(pitch < 1) {
      float pitchHeight = map(pitch,0,1,0,h/3);
      rect(x_off+w/2,y_off+2*h/3,(w/2),h/3-pitchHeight);
    } else {
      float pitchHeight = map(pitch,1,8,0,2*h/3);
      rect(x_off+w/2,y_off+2*h/3-pitchHeight,(w/2),pitchHeight);
    }      
  }
}
