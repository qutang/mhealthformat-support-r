MHEALTH_CSV_TIMESTAMP_HEADER = "HEADER_TIME_STAMP"
MHEALTH_CSV_ACCELEROMETER_CALIBRATED_X_HEADER = "X_ACCELATION_METERS_PER_SECOND_SQUARED"
MHEALTH_CSV_ACCELEROMETER_CALIBRATED_Y_HEADER = "Y_ACCELATION_METERS_PER_SECOND_SQUARED"
MHEALTH_CSV_ACCELEROMETER_CALIBRATED_Z_HEADER = "Z_ACCELATION_METERS_PER_SECOND_SQUARED"

#' @name SensorData.importCsv
#' @title Import mhealth sensor data file and load into memory as data frame in mhealth format
#' @export
SensorData.importCsv = function(filename) {
  op <- options(digits.secs = 3)
  # get the time zone from filename
  tz = gregexpr(pattern = MHEALTH_FILE_TIMESTAMP_TZ_PATTERN, text = filename, perl = TRUE)
  tz = regmatches(filename, tz)[[1]]
  tz = gsub(pattern = "M", replacement = "-", x = tz)
  tz = gsub(pattern = "P", replace = "+", x = tz)
  if (!grepl("csv", filename))
    stop("Please make sure the raw data file is in csv or csv.gz format")
  # read.table supports csv.gz directly
  dat = read.table(
    filename, header = TRUE, sep = MHEALTH_CSV_DELIMITER, quote = "\"", stringsAsFactors = FALSE
  )
  # TODO: use the time zone specified in the filename
  dat$HEADER_TIME_STAMP = as.POSIXct(strptime(dat$HEADER_TIME_STAMP, format = MHEALTH_TIMESTAMP_FORMAT))
  return(dat)
}

#' @name SensorData.importBinary
#' @title Import and decode binary file from the smart watch and load into dataframe as mhealth format
#' @description The default destination directory for the decoded file is stored in .fromBinary folder of current working directory
#' @export
#' @import rJava
SensorData.importBinary = function(filename, dest = file.path(getwd(), ".fromBinary")) {
  if (dir.exists(dest)) {
    unlink(dest, recursive = TRUE, force = TRUE)
  }
  dir.create(dest, recursive = TRUE)
  paras = c(filename, dest)
  J("edu.neu.mhealthformat.utils.converter.WatchBinaryDecoder")$main(.jarray(paras))
  # load iteratively into dataframe
  csvFile = list.files(path = dest, full.names = TRUE)[1]
  return(SensorData.importCsv(csvFile))
}

#' @name SensorData.importGT3X
#' @title Import and decode GT3X files and load into dataframe as mhealth format
#' @export
#' @import rJava
#' @description The default destination folder will be .fromGT3X in current working directory
SensorData.importGT3X = function(filename, dest = file.path(getwd(), ".fromGT3X"), split = FALSE) {
  dir.create(dest, recursive = TRUE)
  if (split) {
    para_split = "SPLIT"
  }else{
    para_split = "NO_SPLIT"
  }
  paras = c(filename, dest, "G_VALUE", "WITH_TIMESTAMP", para_split)
  J("com.qmedic.data.converter.gt3x.ConverterMain")$main(.jarray(paras))

  # load iteratively into dataframe
  csvFiles = list.files(dest, pattern = ".csv", full.names = TRUE, recursive = TRUE)
  datList = lapply(csvFiles, function(file) {
    return(SensorData.importCsv(filename = file))
  })
}


#' @name SensorData.importActigraphCsv
#' @title Import and convert actigraph raw csv files and load into data frame as in mhealth format
#' @export
#' @note Please make sure the actigraph raw csv file has timestamp included
SensorData.importActigraphCsv = function(filename) {
  actigraphHeader = .SensorData.parseActigraphCsvHeader(filename)
  dat = read.table(
    filename, header = FALSE, sep = ",", strip.white = TRUE, skip = 11, stringsAsFactors = FALSE
  );
  dat = dat[,1:4]
  names(dat) = c(
    MHEALTH_CSV_TIMESTAMP_HEADER,
    MHEALTH_CSV_ACCELEROMETER_CALIBRATED_X_HEADER,
    MHEALTH_CSV_ACCELEROMETER_CALIBRATED_Y_HEADER,
    MHEALTH_CSV_ACCELEROMETER_CALIBRATED_Z_HEADER
  )
  timeFormat = ifelse(test = actigraphHeader$imu,
                      yes = ACTIGRAPH_IMU_TIMESTAMP,
                      no = ACTIGRAPH_TIMESTAMP)
  dat[[MHEALTH_CSV_TIMESTAMP_HEADER]] = strptime(x = dat[[MHEALTH_CSV_TIMESTAMP_HEADER]],
                                                 format = timeFormat) + 0.0005
  options(digits.secs = 3);
  return(dat)
}

#' @name SensorData.merge
#' @export
#' @title Merge two or more mhealth data frames and sorted by timestamp, duplicated rows will be removed based on timestamp
#' @note Make sure that the data frame is including timestamps

SensorData.merge = function(listOfData, ...) {
  if (!missing(listOfData)) {
    input = c(listOfData, list(...))
  }else{
    input = list(...)
  }
  dat = Reduce(rbind, input)
  dat = dat[!duplicated(dat[,MHEALTH_CSV_TIMESTAMP_HEADER]),] # remove duplication
  dat = dat[order(dat[MHEALTH_CSV_TIMESTAMP_HEADER]),]
  return(dat)
}

#' @name SensorData.cleanup
#' @export
#' @title Clean up sensor data by removing invalid timestamps, according to matched level (e.g. year, month, day, hour, min, sec)
#' @note Make sure that the data frame is including timestamps
SensorData.cleanup = function(sensorData, level = "year", gt = NULL){
  # extract a valid date
  pattern = switch(level,
         year = "%Y",
         month = "%Y-%m",
         day = "%Y-%m-%d",
         hour = "%Y-%m-%d %H",
         minute = "%Y-%m-%d %H:%M",
         second = "%Y-%m-%d %H:%M:%S")
  validDates = format(sensorData[,MHEALTH_CSV_TIMESTAMP_HEADER], pattern)
  if(is.null(gt)){
    countDates = as.data.frame(table(validDates))
    validDate = as.character(countDates$validDates[countDates$Freq == max(countDates$Freq)])
  }else{
    validDate = as.character(gt)
  }
  sensorData = sensorData[validDates == validDate,]
  return(sensorData)
}

#' @name SensorData.interpolate
#' @title Interpolate the missing points and unify sampling interval for the input sensor data
#' @export
#' @import akima plyr
SensorData.interpolate = function(sensorData, method = "spline_natural", polyDegree = 3){
    nRows = nrow(sensorData);
    nCols = ncol(sensorData);
    colLinearInterp = colwise(approx, x = sensorData[[MHEALTH_CSV_TIMESTAMP_HEADER]], method = "linear", n = nRows)
    colSplineFmmInterp = colwise(spline, x = sensorData[[MHEALTH_CSV_TIMESTAMP_HEADER]], method = "fmm", n = nRows)
    colSplineNaturalInterp = colwise(spline, x = sensorData[[MHEALTH_CSV_TIMESTAMP_HEADER]], method = "natural", n = nRows)
    colAsplineOriginalInterp = colwise(aspline, x = sensorData[[MHEALTH_CSV_TIMESTAMP_HEADER]], method = "original", n = nRows)
    colAsplineImprovedInterp = colwise(aspline, x = sensorData[[MHEALTH_CSV_TIMESTAMP_HEADER]], method = "improved", n = nRows, degree = polyDegree)

    output = switch(method,
                    linear = colLinearInterp(y = sensorData[,2:nCols]),
                    spline_fmm = colSplineFmmInterp(y = sensorData[,2:nCols]),
                    spline_natural = colSplineNaturalInterp(y = sensorData[,2:nCols]),
                    aspline_original = colAsplineOriginalInterp(y = sensorData[,2:nCols]),
                    aspline_improved = colAsplineImprovedInterp(y = sensorData[,2:nCols]))

    names(output)[1] = MHEALTH_CSV_TIMESTAMP_HEADER
    output[,MHEALTH_CSV_TIMESTAMP_HEADER] = as.POSIXlt(output[,MHEALTH_CSV_TIMESTAMP_HEADER], origin = "1970-01-01")
    output = as.data.frame(output)
    return(output)
}

#' @name SensorData.clip
#' @export
#' @title Clip sensor data according to the start and end time
#' @note Make sure that the data frame is including timestamps
SensorData.clip = function(sensorData, startTime, endTime){
  clippedTs = sensorData[[MHEALTH_CSV_TIMESTAMP_HEADER]] >= startTime & sensorData[[MHEALTH_CSV_TIMESTAMP_HEADER]] <= endTime
  return(sensorData[clippedTs,])
}

#' @name SensorData.split
#' @title Split sensor data into list of smaller data frame with meaningful intervals (e.g. hourly, minutely, secondly or daily)
#' @import plyr
#' @export
SensorData.split = function(sensorData, breaks = "hour"){
  result = plyr::dlply(sensorData,.(cut(HEADER_TIME_STAMP, breaks= breaks)), function(x)return(x))
  return(result)
}

#' @name SensorData.plot
#' @title Plot nicely the raw sensor data data frame
#' @export
#' @import ggthemes
SensorData.plot = function(sensorData){
  par(mfrow=c(3,1), mai=c(0.5,0.5,0.5,0.5))
  ts = sensorData[[MHEALTH_CSV_TIMESTAMP_HEADER]]
  x = sensorData[[MHEALTH_CSV_ACCELEROMETER_CALIBRATED_X_HEADER]]
  y = sensorData[[MHEALTH_CSV_ACCELEROMETER_CALIBRATED_Y_HEADER]]
  z = sensorData[[MHEALTH_CSV_ACCELEROMETER_CALIBRATED_Z_HEADER]]
  cols = gdocs_pal()(3)
  par(mai=c(0,1,1,1))
  plot(ts, x, type = "o", col = cols[1], xaxt = "n")
  par(mai=c(0,1,0,1))
  plot(ts, y, type = "o", col = cols[2], xaxt = "n")
  par(mai=c(1,1,0,1))
  plot(ts, z, type = "o", col = cols[3])
}

#' @name SensorData.ggplot
#' @title Plot sensor raw data using ggplot2
#' @export
#' @import lubridate ggplot2 reshape2
#' @param sensorData: should be compatible with the mhealth sensor data format, first column should be HEADER_TIME_STAMP, and the following arbitrary number of columns should be numeric
SensorData.ggplot = function(sensorData){
  data = sensorData
  nCols = ncol(data)
  labelNames = names(data[2:nCols])
  labelNames = c(str_match(labelNames, "[A-Za-z0-9]+_[A-Za-z0-9]+"))
  xlab = "time"
  ylab = "value"

  if(is.null(range)){
    maxy = max(abs(data[,2:nCols]))
    range = c(-maxy, maxy)*1.1
  }

  breaks = pretty_dates(data[,MHEALTH_CSV_TIMESTAMP_HEADER], n = 6)
  minor_breaks = pretty_dates(data[,MHEALTH_CSV_TIMESTAMP_HEADER], n = 30)
  st = breaks[1]
  et = tail(breaks, 1)
  titleText = paste("Raw data plot",
                    paste("\n", st,
                          "\n", et,
                          sep=""))

  data = melt(data, id = c(MHEALTH_CSV_TIMESTAMP_HEADER))

  p = ggplot(data = data, aes_string(x = MHEALTH_CSV_TIMESTAMP_HEADER, y = "value", colour = "variable"))

  p = p + geom_line(lwd = 1.2) +
    labs(title = titleText, x = xlab, y = ylab, colour = "axes") + xlim(c(st, et))

  p = p + scale_x_datetime(breaks = breaks)

  p = p + scale_color_few(labels = labelNames) + theme_bw() + theme(legend.position="bottom")

  p

  return(p)
}

#' @import stringr
.SensorData.parseActigraphCsvHeader = function(filename) {
  headlines = readLines(filename, n = 10, encoding = "UTF-8");

  # Sampling rate
  sr_pattern = ACTIGRAPH_HEADER_SR_PATTERN
  sr = headlines[[1]]
  sr = str_match(sr, sr_pattern)
  sr = as.numeric(sr[2])

  # Firmware code
  fw_pattern = ACTIGRAPH_HEADER_FIRMWARE_PATTERN
  fw = headlines[[1]]
  fw = str_match(fw, fw_pattern)
  fw = fw[2]

  # Software code
  sw_pattern = ACTIGRAPH_HEADER_SOFTWARE_PATTERN
  sw = headlines[[1]]
  sw = str_match(sw, sw_pattern)
  sw = sw[2]

  # Serial number
  sn_pattern = ACTIGRAPH_HEADER_SERIALNUM_PATTERN
  sn = headlines[[2]]
  sn = str_match(sn, sn_pattern)
  sn = sn[2]

  # actigraph type
  at = substr(sn, 1, 3)

  # IMU or not
  if (str_detect(headlines[[1]], "IMU")) {
    imu = TRUE
  }else{
    imu = FALSE
  }

  # Session start time
  st = headlines[[3]]
  sd = headlines[[4]]
  timeReg = "[0-9]{2}(:[0-9]{2}){1,2}+";
  dateReg = "[0-9]+/[0-9]+/[0-9]{4}";
  st = regmatches(st, regexpr(timeReg, st, perl = TRUE))
  sd = regmatches(sd, regexpr(dateReg, sd, perl = TRUE))
  st = paste(sd, st, sep = ' ')
  timeFormat = ACTIGRAPH_TIMESTAMP
  st = strptime(st, timeFormat) + 0.0005
  options(digits.secs = 3);

  # Session download time
  dt = headlines[[6]]
  dd = headlines[[7]]
  timeReg = "[0-9]{2}(:[0-9]{2}){1,2}+";
  dateReg = "[0-9]{2}/[0-9]{2}/[0-9]{4}";
  dt = regmatches(dt, regexpr(timeReg, dt, perl = TRUE))
  dd = regmatches(dd, regexpr(dateReg, dd, perl = TRUE))
  dt = paste(dd, dt, sep = ' ')
  timeFormat = ACTIGRAPH_TIMESTAMP
  dt = strptime(dt, timeFormat) + 0.0005
  options(digits.secs = 3);

  # header object as output
  header = {
  }
  header$sr = sr
  header$fw = fw
  header$sw = sw
  header$sn = sn
  header$st = st
  header$dt = dt
  header$at = at
  header$imu = imu

  return(header)
}

#' @import stringr
.SensorData.parseGT3XHeader = function(filename) {
  fromTicksToMs = function(ticks) {
    TICKS_AT_EPOCH = 621355968000000000;
    TICKS_PER_MILLISECOND = 10000;
    ms = (ticks - TICKS_AT_EPOCH) / TICKS_PER_MILLISECOND;
    sec = ms / 1000;
    return(sec)
  }
  # save in a hidden tmp folder
  tmpFolder = ".fromGT3X"
  unzip(file, overwrite = TRUE, exdir = tmpFolder)
  infoFile = file.path(tmpFolder, ACTIGRAPH_GT3X_HEADER_FILENAME)
  headerStr = paste(readLines(infoFile), collapse = " ")

  # Sampling rate
  sr_pattern = ACTIGRAPH_GT3X_HEADER_SR_PATTERN
  sr = headerStr
  sr = str_match(sr, sr_pattern)
  sr = as.numeric(sr[2])

  # Firmware code
  fw_pattern = ACTIGRAPH_GT3X_HEADER_FIRMWARE_PATTERN
  fw = headerStr
  fw = str_match(fw, fw_pattern)
  fw = fw[2]

  # Serial number
  sn_pattern = ACTIGRAPH_GT3X_HEADER_SERIALNUM_PATTERN
  sn = headerStr
  sn = str_match(sn, sn_pattern)
  sn = sn[2]

  # actigraph type
  at = substr(sn, 1, 3)

  # device type
  device_pattern = ACTIGRAPH_GT3X_HEADER_DEVICETYPE_PATTERN
  deviceType = headerStr
  deviceType = str_match(deviceType, device_pattern)
  deviceType = deviceType[2]

  # Session start time
  st_pattern = ACTIGRAPH_GT3X_HEADER_STARTDATE_PATTERN
  st = str_match(headerStr, st_pattern)
  timeFormat = ACTIGRAPH_TIMESTAMP
  st = fromTicksToMs(as.numeric(st[2]))
  st = as.POSIXct(st, "GMT", origin = "1970-01-01")
  options(digits.secs = 3);

  # Session download time
  dt_pattern = ACTIGRAPH_GT3X_HEADER_DOWNLOADTIME_PATTERN
  dt = str_match(headerStr, dt_pattern)
  timeFormat = ACTIGRAPH_TIMESTAMP
  dt = fromTicksToMs(as.numeric(dt[2]))
  dt = as.POSIXct(dt, "GMT", origin = "1970-01-01")
  options(digits.secs = 3);

  # Dynamic range
  dr_pattern = ACTIGRAPH_GT3X_HEADER_RANGE_PATTERN
  dr = str_match(headerStr, dr_pattern)
  dr = as.numeric(dr[2])
  options(digits.secs = 3);

  # header object as output
  header = {
  }
  header$sr = sr
  header$fw = fw
  header$sw = 'ownparser'
  header$sn = sn
  header$st = st
  header$dt = dt
  header$at = at
  header$dr = dr
  header$deviceType = deviceType

  return(header)
}
