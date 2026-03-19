library(dplyr)
library(lubridate)
library(prophet)
library(ggplot2)
# Load the air quality data
beijing_raw <- read.csv("data/PRSA_data_2010.1.1-2014.12.31.csv")

# Clean the Data (using dplyr)
beijing_data <- beijing_raw %>%
    # Create Date object and and deal with blank values
    mutate(
        ds = make_date(year, month, day),
        pm2.5 = ifelse(pm2.5 == -999, NA, pm2.5)
    ) %>%
    # Aggregate to daily averages
    group_by(ds) %>%
    summarise(
        y_raw = mean(pm2.5, na.rm = TRUE),
        .groups = "drop"
    ) %>%
    # Remove blank days and arrange it chronologically
    filter(!is.na(y_raw)) %>%
    arrange(ds)
#formatting for prophet
prophet_basic_data <- data.frame(ds = beijing_data$ds, y = beijing_data$y_raw)
basic_model<-prophet(prophet_basic_data)
# Forecast
future_basic <- make_future_dataframe(basic_model, periods = 90)
forecast_basic <- predict(basic_model, future_basic)


# Plot the baseline model
plot(basic_model, forecast_basic) +
    ggtitle("Model 1: Prophet Basic Model") +
    xlab("Date") +
    ylab("PM2.5 (μg/m³)") +
    theme_minimal() +
    theme(plot.title = element_text(hjust = 0.5))
#Including chinese new year as a holiday
# Create the holiday dataframe
chinese_new_year <- data.frame(
    holiday = "chinese_new_year",
    ds = as.Date(c("2010-02-14", "2011-02-03", "2012-01-23",
                   "2013-02-10", "2014-01-31")),
    lower_window = -1,
    upper_window = 2
)

# Run the model with holidays
prophet_model2 <- prophet(prophet_basic_data, holidays = chinese_new_year)
future_model2 <- make_future_dataframe(prophet_model2, periods = 90)
forecast_model2 <- predict(prophet_model2, future_model2)

# Plot the components
prophet_plot_components(prophet_model2, forecast_model2)
plot(prophet_model2, forecast_model2) +
    ggtitle("Model 2: Prophet Model with Chinese New Year") +
    xlab("Date") +
    ylab("PM2.5 (μg/m³)") +
    theme_minimal() +
    theme(plot.title = element_text(hjust = 0.5))
#Dealing with Heteroscedacity
#Apply log transformation
prophet_data2 <- beijing_data %>%
    mutate(y = log1p(y_raw))
##Initialise the model (keeping Chinese New Year)
prophet_log_model <- prophet(
    holidays = chinese_new_year,
    seasonality.mode = "additive" # Must be additive because the data is logged
)

# Fit the model to our logged data
prophet_log_model <- fit.prophet(prophet_log_model, prophet_data2)

#Forecast 90 days into the future
future_log_model <- make_future_dataframe(prophet_log_model, periods = 90)
forecast_pro <- predict(prophet_log_model, future_log_model)

# Plot
# We use expm1() to reverse the log1p() so its easier to read
ggplot() +
    # The actual data points (semi-transparent gray)
    geom_point(data = prophet_data2, aes(x = as.Date(ds), y = expm1(y)),
               color = "gray30", size = 0.5, alpha = 0.4) +
    # The blue confidence interval
    geom_ribbon(data = forecast_pro, aes(x = as.Date(ds), ymin = expm1(yhat_lower), ymax = expm1(yhat_upper)),
                fill = "blue", alpha = 0.2) +
    # The blue forecast line
    geom_line(data = forecast_pro, aes(x = as.Date(ds), y = expm1(yhat)),
              color = "blue", linewidth = 0.8) +
    ggtitle("Model 3: Log Transformed Prophet Model") +
    ylab("PM2.5 (μg/m³)") +
    xlab("Date") +
    theme_minimal()
