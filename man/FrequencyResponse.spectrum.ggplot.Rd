% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/FrequencyResponse.R
\name{FrequencyResponse.spectrum.ggplot}
\alias{FrequencyResponse.spectrum.ggplot}
\title{Plot fft frequency response for input sensor data.}
\usage{
FrequencyResponse.spectrum.ggplot(frData, scale = "normal",
  resolution = 0.01, label = TRUE)
}
\arguments{
\item{frData}{should be compatible with frequency response data format, with the first column be the frequencies, following by numeric columns}

\item{scale}{"normal" or "log" or "db", plot values in normal scale or log10 or dB scale. Default is "normal".}

\item{resolution}{plot resolution for frequencies. If resolution is higher than the actual data resolution, it will do nothing, if resolution is lower than the actual data, it will skip some of the data points evenly. Default is 0.01Hz.}

\item{label}{if TRUE, show dominant frequency values.}
}
