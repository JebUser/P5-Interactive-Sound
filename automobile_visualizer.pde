import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress pureData;

ArrayList<Car> cars = new ArrayList<Car>();
int currentCarIndex = 0;
int lastSentCarIndex = -1;
float transitionProgress = 0;
boolean isPlaying = false;
boolean lastPlayState = false;

int canvasWidth = 1200;
int canvasHeight = 800;

void setup() {
  size(1200, 800);
  colorMode(HSB, 360, 100, 100);
  oscP5 = new OscP5(this, 12000);
  pureData = new NetAddress("192.168.1.25", 8000);
  loadCarData();
  println("Data loaded: " + cars.size() + " cars");
  println("Press SPACE to start/stop sonification");
  println("Press LEFT/RIGHT arrows to navigate manually");
  println("");
  println("OSC SETUP:");
  println("- /car/data: Enviado SOLO cuando cambia de auto (60-90)");
  println("- /car/play: Enviado cuando presiona ESPACIO (1=play, 0=pause)");
}

void draw() {
  background(0);
  if (isPlaying && transitionProgress < 1.0) {
    transitionProgress += 0.01;
    if (transitionProgress >= 1.0) {
      currentCarIndex++;
      if (currentCarIndex >= cars.size()) {
        currentCarIndex = 0;
      }
      transitionProgress = 0;
    }
  }

  if (cars.size() > 0) {
    Car currentCar = cars.get(currentCarIndex);
    visualizeCar(currentCar);
    if (currentCarIndex != lastSentCarIndex) {
      sendCarDataToPureData(currentCar);
      lastSentCarIndex = currentCarIndex;
    }
  }

  drawUI();
}

void loadCarData() {
  Table table = loadTable("Automobile.csv", "header");

  for (TableRow row : table.rows()) {
    String name = row.getString("name");
    float mpg = row.getFloat("mpg");
    int cylinders = row.getInt("cylinders");
    float displacement = row.getFloat("displacement");

    float horsepower = 0;
    try {
      horsepower = row.getFloat("horsepower");
    } catch (Exception e) {
      horsepower = 100;
    }

    float weight = row.getFloat("weight");
    float acceleration = row.getFloat("acceleration");
    int modelYear = row.getInt("model_year");
    String origin = row.getString("origin");

    cars.add(new Car(name, mpg, cylinders, displacement, horsepower, 
                     weight, acceleration, modelYear, origin));
  }
}

void visualizeCar(Car car) {
  fill(360, 0, 100);
  textSize(24);
  textAlign(CENTER);
  text(car.name, width/2, 40);

  float mpgSize = map(car.mpg, 9, 46, 50, 200);
  float mpgHue = map(car.mpg, 9, 46, 0, 120);
  fill(mpgHue, 80, 90);
  ellipse(300, 250, mpgSize, mpgSize);
  fill(360, 0, 100);
  textSize(16);
  textAlign(CENTER);
  text("MPG: " + nf(car.mpg, 1, 1), 300, 250);

  float hpHeight = map(car.horsepower, 46, 230, 50, 400);
  fill(30, 80, 90);
  rect(500, 450 - hpHeight, 60, hpHeight);
  fill(360, 0, 100);
  text("HP", 530, 470);
  text(int(car.horsepower), 530, 490);

  float weightSize = map(car.weight, 1600, 5200, 80, 180);
  fill(240, 70, 80);
  rect(700, 250 - weightSize/2, weightSize, weightSize/2);
  fill(360, 0, 100);
  text("Weight", 700 + weightSize/2, 270);
  text(int(car.weight) + " lbs", 700 + weightSize/2, 290);

  float cylinderSpacing = 40;
  for (int i = 0; i < car.cylinders; i++) {
    fill(180, 60, 80);
    ellipse(200 + i * cylinderSpacing, 500, 30, 30);
  }
  fill(360, 0, 100);
  text("Cylinders: " + car.cylinders, 300, 550);

  color originColor = getOriginColor(car.origin);
  fill(originColor);
  rect(50, 600, 100, 50);
  fill(360, 0, 100);
  text(car.origin.toUpperCase(), 100, 630);

  fill(360, 0, 100);
  textSize(14);
  textAlign(LEFT);
  text("Year: 19" + car.modelYear, 900, 150);
  text("Displacement: " + nf(car.displacement, 1, 1), 900, 180);
  text("Acceleration: " + nf(car.acceleration, 1, 1) + " sec", 900, 210);
}

void sendCarDataToPureData(Car car) {
  println("\n========== CAR " + (currentCarIndex + 1) + " ==========");
  println("car origin: " + originToNumber(car.origin));
  println("car mpg: " + int(car.mpg));
  println("car horsepower: " + int(car.horsepower));
  println("car weight: " + int(car.weight));
  println("car cylinders: " + car.cylinders);
  println("car acceleration: " + int(car.acceleration));

  float mpgValue = car.mpg;
  float hpValue = car.horsepower;
  int cylValue = car.cylinders;
  float weightValue = car.weight;
  int originNum = originToNumber(car.origin);

  float rawValue = (mpgValue * 3) + (hpValue / 5) - (cylValue * 2) + (weightValue / 100) + originNum;
  float mappedValue = map(rawValue, 37.33, 232.4, 60, 90);
  int finalValue = round(mappedValue);

  println("car data: " + finalValue);
  println("=====================================\n");

  OscMessage msgData = new OscMessage("/carData");
  msgData.add(finalValue);
  oscP5.send(msgData, pureData);
}

void sendPlayToggleToPureData() {
  int playValue = isPlaying ? 1 : 0;
  println(">>> PLAY TOGGLE ENVIADO: " + playValue);
  OscMessage msgPlay = new OscMessage("/carPlay");
  msgPlay.add(playValue);
  oscP5.send(msgPlay, pureData);
}

int originToNumber(String origin) {
  if (origin.equals("usa")) {
    return 1;
  } else if (origin.equals("japan")) {
    return 2;
  } else {
    return 3;
  }
}

color getOriginColor(String origin) {
  if (origin.equals("usa")) {
    return color(0, 80, 90);
  } else if (origin.equals("japan")) {
    return color(120, 80, 90);
  } else {
    return color(240, 80, 90);
  }
}

void drawUI() {
  fill(360, 0, 50);
  rect(50, 700, width - 100, 20);
  fill(180, 70, 80);
  float progressWidth = map(currentCarIndex, 0, cars.size(), 0, width - 100);
  rect(50, 700, progressWidth, 20);

  fill(360, 0, 100);
  textSize(12);
  textAlign(LEFT);
  text("Car " + (currentCarIndex + 1) + " / " + cars.size(), 50, 750);
  text(isPlaying ? "PLAYING (1)" : "PAUSED (0)", width - 150, 750);
  text("OSC: /car/data <60-90>  /car/play <0|1>", 50, 770);
}

void keyPressed() {
  if (key == ' ') {
    isPlaying = !isPlaying;
    if (isPlaying != lastPlayState) {
      sendPlayToggleToPureData();
      lastPlayState = isPlaying;
    }
  } else if (keyCode == LEFT && currentCarIndex > 0) {
    currentCarIndex--;
    transitionProgress = 0;
  } else if (keyCode == RIGHT && currentCarIndex < cars.size() - 1) {
    currentCarIndex++;
    transitionProgress = 0;
  }
}

class Car {
  String name;
  float mpg;
  int cylinders;
  float displacement;
  float horsepower;
  float weight;
  float acceleration;
  int modelYear;
  String origin;

  Car(String name, float mpg, int cylinders, float displacement, 
      float horsepower, float weight, float acceleration, 
      int modelYear, String origin) {
    this.name = name;
    this.mpg = mpg;
    this.cylinders = cylinders;
    this.displacement = displacement;
    this.horsepower = horsepower;
    this.weight = weight;
    this.acceleration = acceleration;
    this.modelYear = modelYear;
    this.origin = origin;
  }
}
