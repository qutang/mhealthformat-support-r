% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/SensorData.R
\name{SensorData.split}
\alias{SensorData.split}
\title{Split sensor data into list of smaller data frame with meaningful intervals (e.g. hourly, minutely, secondly or daily)}
\usage{
SensorData.split(sensorData, breaks = "hour")
}
\arguments{
\item{sensorData}{input dataframe that matches mhealth specification.}

\item{breaks}{"sec","min","hour","day","week","month","quarter" or "year"; or preceded by integer and space.}
}
\value{
list of splitted dataframes
}
