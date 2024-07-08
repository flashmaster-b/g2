class Mapping {
  int id;              // ID of grain to madulate
  String in, out;      // in = sensor input, out = mapping output
  float min, max;      // min / max values of mapping output
  float inMin, inMax;  // if you want to map to other limits than Sensuino2 min/max values, has to set fixedInLimits flag
  boolean gliding, fixedInLimits;

  Mapping(int id_, String in_, String out_, float min_, float max_, boolean gliding_, float inMin_, float inMax_) {
    id=id_;
    in = in_;
    out = out_;
    min = min_;
    max = max_;
    gliding = gliding_;
    inMin = inMin_;
    inMax = inMax_;
    fixedInLimits = true;
  }
  
  Mapping(int id_, String in_, String out_, float min_, float max_, boolean gliding_) {
    id=id_;
    in = in_;
    out = out_;
    min = min_;
    max = max_;
    gliding = gliding_;
    fixedInLimits = false;
  }
  
  Mapping(int id_, String in_, String out_, boolean gliding_) {
    id = id_;
    in = in_;
    out = out_;
    gliding = gliding_; 
    fixedInLimits = false;
    max = mappingOutMax.get(out);
    min = mappingOutMin.get(out);
  }
}
