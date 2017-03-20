# Author: BN
# 2017

# TODO: switch between the api keys automatically

#Clear all history.
clear all; clc;

# Prevent to pause the script when the command window is full.
page_screen_output(0);

# Disable warnings (NOT errors) which is appear when file/dir modifications happen.
warning('off', 'all');


# Global constants

# USER DEFINIED VARIABLES
# You can use two api key, because of the limitations.
global API_KEY_1 = '****************';
global API_KEY_2 = '****************';

# Min and max temperature to filter the invalid values like -9999 °C.
global TEMP_RANGE = [-50, 50];

# URLs
global HUNGARY_BORDERS = 'http://www.agt.bme.hu/~piri/hungary_border.dat';
global HUNGARY_RIVERS = 'http://www.agt.bme.hu/~piri/hungarian_rivers.dat';
global HUNGARY_LAKES = 'http://www.agt.bme.hu/~piri/hungarian_lakes.dat';
global WEATHER_STATIONS = 'http://www.aviationweather.gov/static/adds/metars/stations.txt';
global WEATHER_API_URL = {'', ''};
global JSONLAB_URL = 'https://github.com/fangq/jsonlab/archive/v1.5.zip';

# File names
global JSONLAB_DIR_NAME = 'jsonlab';
global STATIONS_FILE_NAME = 'stations.txt';
global HUNGARY_BORDER_FILE_NAME = 'hungary_border.dat';
global HUNGARY_RIVERS_FILE_NAME = 'hungarian_rivers.dat';
global HUNGARY_LAKES_FILE_NAME = 'hungarian_lakes.dat';

# Some extra stations for Hungary.
global EXTRA_STATIONS_HUNGARY = {'LZLU', 'LZKZ', 'LRSM', 'LRAR', 'LDOS', 'LJMB', 'LOWW'};

# Store the data for our stations. (Station name, station code, lat, long, elev)
global stations;

# Round hours. The user should choose from this array when want to display the temperatures.
global HOURS = {'00:00'; '01:00'; '02:00'; '03:00'; '04:00'; '05:00'; '06:00'; '07:00'; '08:00'; '09:00'; '10:00'; '11:00';
                '12:00'; '13:00'; '14:00'; '15:00'; '16:00'; '17:00'; '18:00'; '19:00'; '20:00'; '21:00'; '22:00'; '23:00'};

# FUNCTIONS

# Initialize the api urls.
function isInit = initApiUrls()
  # Init.
  isInit = false;

  global API_KEY_1;
  global API_KEY_2;
  global WEATHER_API_URL;

  # The first key cannot be empty.
  if length(API_KEY_1) > 0
    WEATHER_API_URL(1) = ['http://api.wunderground.com/api/', API_KEY_1, '/'];
    isInit = true;
  end
  # Second key is optional.
  if length(API_KEY_2) > 0
    WEATHER_API_URL(2) = ['http://api.wunderground.com/api/', API_KEY_2, '/'];
  end
  return;
end

# Get JSONLAB if don't have already.
function succes = initJsonlab()
  global JSONLAB_DIR_NAME;
  global JSONLAB_URL;

  succes = false;

  if !exist(JSONLAB_DIR_NAME)
    printf('Downloading JSONLab... ');
    urlwrite(JSONLAB_URL, 'jsonlab.zip');
    unzip('jsonlab.zip');
    delete('jsonlab.zip');
    rename('jsonlab-1.5', JSONLAB_DIR_NAME);
    printf('DONE\r\n');
  end

  # Add the jsonlab directory to the path.
  addpath([pwd '/jsonlab']);
  succes = true;
  return;
end

# Validate the temperature.
function isTempValid = validateTemp(temp)
  global TEMP_RANGE;
  isTempValid = false;

  # Convert the temp string to int.
  temp = str2num(temp);

  if temp > min(TEMP_RANGE) && temp < max(TEMP_RANGE)
    isTempValid = true;
  end

  return;
end

# Check the date from user input.
function isDateValid = validateDate(date)
  # Init
  isDateValid = false;
  # Date checking pattern.
  datePattern = '\d{4}-\d{2}-\d{2}';

  if length(date) != 10
    return;
  end

  # If not match with the required pattern return false.
  if length(regexp(date, datePattern)) != 1
    return;
  end

  currentYear = clock()(1);
  currentMonth = clock()(2);
  currentDay = clock()(3);

  year = str2num(date(1:4));
  month = str2num(date(6:7));
  day = str2num(date(9:10));

  # Check the values.
  # The year cannot be bigger than the current year.
  if year > currentYear || month > 12 || day > 31
    return;
  end
  # If this year selected the month cannot be bigger too.
  if year == currentYear && month > currentMonth
    return;
  end

  # If the year and the month is the current the day cannot be bigger.
  if year == currentYear && month == currentMonth && day > currentDay
    return;
  end

  # The date is valid.
    isDateValid = true;
  return;

end

# Validate counrty name from user input.
function isCountryValid = validateCountryName(name)
  isCountryValid = false;
  pattern = '\w{3,}';
  if length(regexpi(name, pattern)) != 1
    return;
  end
  isCountryValid = true;
  return;
end

# Extract the informations from the lines and return as a cell array.
function stationCell = extractStation(textLine)
  # Name of the stations.
  stationCell{1,1} = strtrim(textLine(4:19));
  # Station id for the api calls.
  stationCell{1,2} = strtrim(textLine(21:24));
  # Latitude.
  stationCell{1,3} = strtrim(textLine(40:45));
  # Longitude.
  stationCell{1,4} = strtrim(textLine(48:54));
  # Elevation.
  stationCell{1,5} = strtrim(textLine(56:59));
  return;
end

# Convert the lat/long from the station to float.
function [y, x] = getStationCoordinates(station)
  # Init
  y = 0;
  x = 0;
  # Cut the letter, replace the space to point then convert to number.
  y = station{3};
  x = station{4};
  y = y(1:length(y)-1);
  x = x(1:length(x)-1);
  y = str2num(strrep(y, ' ', '.'));
  x = str2num(strrep(x, ' ', '.'));
  return
end


# Parse and extract the necessary informations from the api response.
function stationValuesDb = extractData(apiResponse)
  # Init
  stationValuesDb = struct();
  try
    # First parse the response.
    parsedData = loadjson(apiResponse);
    # Get the history.
    parsedData = parsedData.history.observations;

    # Extract the values.
    for i = 1:length(parsedData)
      time = [parsedData{1,i}.date.hour, ':', parsedData{1,i}.date.min];
      temp = parsedData{1,i}.tempm;

      # Add to the struct.
      stationValuesDb.(time) = strsplit(temp, '.'){1,1};
    end
  catch
    stationValuesDb = '';
  end

  return;
end

# Download and parse the weather data for the station on the given day.
function weatherData = getWeatherData(stationName, date)
  # Init
  weatherData = '';
  global WEATHER_API_URL;
  if length(WEATHER_API_URL{1,1}) > 0
    # Create the full url.
    url = [WEATHER_API_URL{1,1}, 'history_', strrep(date, '-', ''), '/q/', stationName, '.json'];
    # Download it.
    printf('Downloading weather data from API_1...');
    downloadedData = urlread(url);
    printf('DONE\r\n');
    # I have to get a response without data, to analyze that response.
    hasResponse = true;
  end

  if length(WEATHER_API_URL{1,2}) > 0 && !hasResponse
    # Create the full url.
    url = [WEATHER_API_URL{1,2}, 'history_', strrep(date, '-', ''), '/q/', stationName, '.json'];
    # Download it.
    printf('Downloading weather data from API_2...');
    downloadedData = urlread(url);
    printf('DONE\r\n');
  end

  # Now parse and extract the downloaded JSON.
  weatherData = extractData(downloadedData);

  return;
end

# Create a time string from the given numbers(integers) in HH:MM format.
function timeString = createTimeStr(hour, minute)
  timeString = false;

  # Convert to string.
  hour = num2str(hour);
  minute = num2str(minute);

  if length(hour) == 1
    hour = ['0', hour];
  end
  if length(minute) == 1
    minute = ['0', minute];
  end

  timeString = [hour, ':', minute];
  return;
end

# Get the temperature for the given time.
function temp = getTemp(station, time)
  temp = false;
  minDiffIndex = 1;

  # Check is the time exists in the station or not.
  if isfield(station, time)
    temp = station.(time);
    # If the temperature is invalid return false.
    if !validateTemp(temp)
      temp = false;
    end

    return;
  end

  # Seems there are no field in the station.
  # Let's find the nearest and get the value from it. (Should be interpolate in the future)
  while temp == false
    hour = str2num(strsplit(time, ':'){1,1});
    minute = str2num(strsplit(time, ':'){1,2});

    # First increase and check the time.
    minute += minDiffIndex;

    if minute >= 60
      hour += 1;
      minute -= 60;
    end

    timeString = createTimeStr(hour, minute);

    if isfield(station, timeString)
      temp = station.(timeString);
      # If the temperature is invalid return false.
      if !validateTemp(temp)
        temp = false;
        continue;
      else
        return;
      end
    end


    # Now decrease and check the time.
    # Minute is already increased.
    minute -= 2 * minDiffIndex;

    if minute < 0
      hour -= 1;
      minute += 60;
    end

    timeString = createTimeStr(hour, minute);

    if isfield(station, timeString)
      temp = station.(timeString);
      # If the temperature is invalid return false.
      if !validateTemp(temp)
        temp = false;
        continue;
      else
        return;
      end
    end

      # Increase the min diff index.
      minDiffIndex += 1;
  end
end

# START MAIN

# First init the api urls.
if !initApiUrls()
  errordlg('You must define at least one API key!', 'API error');
  return;
end

# Initialize JSONLab.
if !initJsonlab()
  errordlg('Cannot initialize JSONLab.', 'Init error');
  return;
end

# Download some constants file if they are not exist yet.
if !exist(STATIONS_FILE_NAME)
  printf('Downloading weatherstations... ');
  urlwrite(WEATHER_STATIONS, STATIONS_FILE_NAME);
  printf('DONE\r\n');
end

if !exist(HUNGARY_BORDER_FILE_NAME)
  printf('Downloading the border of Hungary...');
  urlwrite(HUNGARY_BORDERS, HUNGARY_BORDER_FILE_NAME);
  printf('DONE\r\n');
end

if !exist(HUNGARY_RIVERS_FILE_NAME)
  printf('Downloading the rivers of Hungary...');
  urlwrite(HUNGARY_RIVERS, HUNGARY_RIVERS_FILE_NAME);
  printf('DONE\r\n');
end

if !exist(HUNGARY_LAKES_FILE_NAME)
  printf('Downloading the lakes of Hungary...');
  urlwrite(HUNGARY_LAKES, HUNGARY_LAKES_FILE_NAME);
  printf('DONE\r\n');
end

# Check if the file downloaded and saved correctly.
if !exist(STATIONS_FILE_NAME) || !exist(HUNGARY_BORDER_FILE_NAME) || !exist(HUNGARY_RIVERS_FILE_NAME) || !exist(HUNGARY_LAKES_FILE_NAME) || !exist(JSONLAB_DIR_NAME)
  errordlg('Cannot read the necessary files. Maybe something is wrong with your network connection or with the permission of the working directory. The script now exit', 'File error');
  return;
end

# Ask the user for a country name. Loop until get a result.
while true

  # Get the country name from an input dialog.
  countryName = inputdlg('Please add your country name in english.', 'Choose your country');

  if length(countryName) > 0
    # Get the country name string from the cell array.
    countryName = countryName{1,1};
  end

  # Check the the user input.
  if !validateCountryName(countryName)
    errordlg('Invalid country name! Please try again.', 'Input error');
    continue;
  end

  # Regex pattern for the counrty name in the lines.
  counrtyNamePattern = ['^', countryName];

  # Open the file which contains the stations.
  fid = fopen(STATIONS_FILE_NAME, 'r');

  # Just a variable for switch between the reading states.
  readSwitch = false;
  # Store the stations cell arrays.
  stations = {};

  # Search the country's block of stations.
  while !feof(fid)
    # Read and store the current line.
    line = fgetl(fid);

    # If reach the end of the block.
    if readSwitch && strcmp(line, '')
      break;
    end

    # If the switch is true, read and store all the lines.
    if readSwitch
      stations{length(stations) + 1} = extractStation(line);
    end

    # Reach the block so start reading the data. Find the country name with regex.
    if !readSwitch && length(regexpi(line, counrtyNamePattern)) > 0
      readSwitch = true;
    end
  end

  # If the stations array is empty throw an error and exit from this script.
  if length(stations) == 0
    errordlg('No stations found. Please try again.', 'Error');
    continue;
  else
    printf('The chosen country is %s\r\n', upper(countryName));
    break;
  end
end

# If the country is Hungary add some extra station for the cell array.
# This is only necessary for my task in the university.
if length(regexpi('HUNGARY', counrtyNamePattern)) > 0
  while !feof(fid)
    # Read and store the current line.
    line = fgetl(fid);
    # If the line is long enough and station ID is in the extra stations.
    if length(line) > 24 && sum(strcmp(line(21:24), EXTRA_STATIONS_HUNGARY)) == 1
      stations{length(stations) + 1} = extractStation(line);
    end
  end
end

# Close the file.
fclose(fid);

# We should have all the stations now.
# Let's get the day we want to display.
while true
  day = inputdlg('Add the date in "YYYY-MM-DD" format. e.g. 2016-05-09', 'Choose a day');

  # Extract the string.
  if length(day) > 0
    day = day{1,1};
  end

  if !validateDate(day)
    errordlg('The given date is invalid. Please try again.', 'Input error');
    continue;
  else
    printf('The chosen day is %s.\r\n', day);
    break;
  end
end

# Create the struct. This will store the all the data for the given day.
stationsDb = struct();

# Download the weather data for the stations.
for i = 1:length(stations)
  stationId = stations{1,i}{1,2};
  stationName = stations{1,i}{1,1};

  # Check the station ID. (ICAO = 4-character international id)
  if length(stationId) != 4
    printf('No station ID found for the %s station.\r\n', stationName);
    continue;
  end

  printf('Downloading data for station: %s (%s) ... \r\n', stationId, stationName);
  stationData = getWeatherData(stationId, day);

  if length(stationData) == 0
    printf('No data found for the station: %s (%s) \r\n', stationId, stationName);
    continue;
  end

  # Add to the struct.
  stationsDb.(stationId) = stationData;
end

# If any file remained open close it.
fclose('all');

# The names of the downloaded stations.
downloadedStationNames = fieldnames(stationsDb);

# We need at least three station.
if length(downloadedStationNames) <= 3
  errordlg('Not enough stations. The script now exit.', 'Missing data error');
  return;
end

# Give some information to the user.
msgbox('Click on the map to get the temparature at the point. If you want to choose another time just right click.', 'Info');

# Loop to let the user choose multiple times.
while true

  # Let the user chose the time.
  timeIndex = menu('Choose a time:', HOURS);
  chosenTime = HOURS(timeIndex){1,1};


  # Use only one window (figure) for all plots. 
  figure(1);
  hold on;  

  # Store the coordinates and the temperatures.
  X = [];
  Y = [];
  temps = [];

  # Get all the data from the stations that we will plot.
  for i = 1:length(stations)
    stationId = stations{1,i}{1,2};

    # Check if we have data for the station.
    if sum(strcmp(stationId, downloadedStationNames)) == 0 || length(fieldnames(stationsDb.(stationId))) == 0
      continue;
    end

    # Get the temperature.
    temp = getTemp(stationsDb.(stationId), chosenTime);

    if temp == false
      continue;
    end

    temps = [temps; str2num(temp)];
    # Get the stations coordinates
    [x, y] = getStationCoordinates(stations{i});
    # and append them to the vector.
    X = [X; x];
    Y = [Y; y];
  end

  # Min and max values for the grid.
  Xmin = min(X);
  Xmax = max(X);
  Ymin = min(Y);
  Ymax = max(Y);

  # Create the grid for the interpolation.
  yVector = Ymin:0.01:Ymax;
  xVector = Xmin:0.01:Xmax;

  # Create the meshgrid.
  [Xi Yi] = meshgrid(xVector, yVector);

  # Create interpolated mesh for the temperature.
  ZiTemp = griddata(X, Y, temps, Xi, Yi, 'linear');

  # Don't really now why, but have to do this workaround for the correct displaying.
  # Flip the matrix left-right them rotate by 90 degree in clockwise.
  Zi = rot90(fliplr(ZiTemp));

  # Plot the interpolated matrix as an image.
  imagesc(Yi(:,1), Xi(1,:), Zi);
  axis xy;
  title('Temperature map');
  colorbar;
  colormap(jet);

  # Plot the borders and waters if the country is Hungary.
  if length(regexpi('HUNGARY', counrtyNamePattern)) > 0
    data = load(HUNGARY_BORDER_FILE_NAME);
    y1 = data(:,1);
    x1 = data(:,2);
    plot(y1, x1, 'm', 'linewidth', 3);
    data = load(HUNGARY_LAKES_FILE_NAME);
    y2 = data(:,1);
    x2 = data(:,2);
    plot(y2, x2, 'b', 'linewidth', 2);
    data = load(HUNGARY_RIVERS_FILE_NAME);
    y3 = data(:,1);
    x3 = data(:,2);
    plot(y3, x3, 'b', 'linewidth', 2);
  end

  # Plot all the stations even if it doesn't have temperature data.
  for i = 1:length(stations)
    [xs, ys] = getStationCoordinates(stations{i});
    stationName = stations{i}{1,1};

    plot(ys, xs, 'kd', 'markersize', 15, 'markerfacecolor', 'k');
    text(ys + 0.15 , xs + 0.05, stationName, 'color', 'black', 'fontsize', 12);
  end

  # Plot the temperature of the stations.
  for i = 1:length(temps)
    text(Y(i) + 0.15, X(i) - 0.05, num2str(temps(i)), 'color', 'black', 'fontsize', 10);
  end
  # Until the user right click wait for mouse inputs.
  while true
    [y, x, button] = ginput(1);
    if button == 3
      close all;
      break;
    end
    msgbox(sprintf('The temperature is %.1f °C at point %f, %f', interp2(Xi, Yi, ZiTemp, x, y), x, y), 'Clicked');
  end
end
