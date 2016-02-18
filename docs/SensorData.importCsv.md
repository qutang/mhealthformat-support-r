---
layout: doc
title: API Document
---

#### `SensorData.importCsv`: Import mhealth sensor data file and load into memory as data frame in mhealth format. ####

#### Usage ####

```r
SensorData.importCsv(filename, violate = FALSE)
```

#### Arguments ####

* `filename`: full file path of input sensor data file.
* `violate`: violate file name convention, ignore time zones and other information in file name


#### Seealso ####


 [`SensorData.importBinary`](SensorData.importBinary.html), [`SensorData.importGT3X`](SensorData.importGT3X.html), [`SensorData.importActigraphCsv`](SensorData.importActigraphCsv.html)


#### Note ####


 input file must match mhealth specification. Note that the time zone of timestamps will be based on local computer instead of the filename, this needs to be changed.

