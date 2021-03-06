% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/AnnotationData.R
\name{AnnotationData.clip}
\alias{AnnotationData.clip}
\title{Clip annotation data according to the start and end time}
\usage{
AnnotationData.clip(annotationData, startTime, endTime)
}
\arguments{
\item{annotationData}{annotation data frame that matches mhealth specification.}

\item{startTime}{POSIXct date object for start timestamp.}

\item{endTime}{POSIXct date object for start timestamp.}
}
\value{
clipped annotation dataframe
}
\note{
Make sure that the data frame is compatible with mhealth annotation data file format.
}
