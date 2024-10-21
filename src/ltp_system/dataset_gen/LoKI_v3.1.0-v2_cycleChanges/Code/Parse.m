% LoKI-B solves a time and space independent form of the two-term 
% electron Boltzmann equation (EBE), for non-magnetised non-equilibrium 
% low-temperature plasmas excited by DC/HF electric fields from 
% different gases or gas mixtures.
% Copyright (C) 2018 A. Tejero-del-Caz, V. Guerra, D. Goncalves, 
% M. Lino da Silva, L. Marques, N. Pinhao, C. D. Pintassilgo and
% L. L. Alves
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.

classdef Parse
  
  properties (Constant = true)
    
    inputFolder = 'Input';
    commentChar = '%';
    wildCardChar = '*';
    stateRegExp = ['\s*(?<quantity>\d+\s*)?(?<gasName>\w+)\((?<ionCharg>[+-])?'...
      '(?:,)?(?<eleLevel>[\w''.\[\]/+*-]+){1}(?:,v=)?(?<vibLevel>(?<=,v=)[\w+*-]+)?'...
      '(?:,J=)?(?<rotLevel>(?<=,J=)[\d+*-]+)?\)\s*'];
    electronRegExp = '\s*(?<quantity>\d+)?((?:[eE]\s*)(?=[\s]|[+][^\(])|(?:[eE]$))';
    wallRegExp = '\s*(?<gasName>[wW][aA][lL][lL])\s*';
    
  end
  
  methods (Static)
    
    function [setupStruct, unparsed] = setupFile(fileName)
    % setupFile Reads the configuration file for the simulation and returns
    % a setup structure with all the information.
      
      [structArray, unparsed] = file2structArray([Parse.inputFolder filesep fileName]);
      setupStruct = structArray2struct(structArray);
      
    end
    
    function LXCatEntryArray = LXCatFiles(fileName)
    % LXCatFiles Reads LXCat files, parse their content and returns an
    % structure array 'LXCatEntryArray' with all the information.
      
      % definition of regular expressions to parse LXCat file
      LXCatRegExp1 = 'PROCESS: (?<reactants>.+?)(?<direction>->|<->) (?<products>.+?), (?<type>\w+)';
      LXCatRegExp2 = 'E = (?<threshold>[\d.e+-]+) eV';
      LXCatRegExp3 = ['\[(?<reactants>.+?)(?<direction>->|<->)(?<products>.+?), (?<type>\w+)' ...
        '(?<subtype>, momentum-transfer)?\]'];
      % create a cell array with filenames in case only one file is
      % received as input
      if ischar(fileName)
        fileName = {fileName};
      end
      % create an empty struct array of LXCat entries 
      LXCatEntryArray = struct.empty;
      % loop over different LXCat files that have to be read
      for i = 1:length(fileName)
        % open LXCat file
        fileID = fopen([Parse.inputFolder filesep fileName{i}], 'r');
        if fileID<0
          error(' Unable to open LXCat file: %s\n', fileName{i});
        end
        % parse LXCat file
        while ~feof(fileID)
          description = regexp(fgetl(fileID), LXCatRegExp1, 'names', 'once');
          if ~isempty(description)
            parameter = regexp(fgetl(fileID), LXCatRegExp2, 'names', 'once');
            description = regexp(fgetl(fileID),LXCatRegExp3, 'names', 'once');
            while ~strncmp(fgetl(fileID), '-----', 5)
            end
            rawCrossSection = (fscanf(fileID, '%f', [2 inf]));
            % add LXCat entry information into LXCatEntry struct array
            LXCatEntryArray = addLXCatEntry(description, parameter, rawCrossSection, LXCatEntryArray);
          end
        end
        % close LXCat file
        fclose(fileID);
      end

    end

    function chemEntryArray = chemFiles(fileName)
    % chemFiles Reads ".chem" files, parse their content and returns an
    % structure array 'chemEntryArray' with all the information.
      
      % create a cell array with filenames in case only one file is received as input
      if ischar(fileName)
        fileName = {fileName};
      end
      % create an empty struct array of chem entries 
      chemEntryArray = struct.empty;
      % loop over different ".chem" files that have to be read
      for i = 1:length(fileName)
        % open ".chem" file
        fileID = fopen([Parse.inputFolder filesep fileName{i}], 'r');
        if fileID<0
          error(' Unable to open ''.chem'' file: %s\n', fileName{i});
        end
        % parse ".chem" file
        lineNumber = 1;
        while ~feof(fileID)
          cleanLine = removeComments(strtrim(fgetl(fileID)));
          if isempty(cleanLine)
            lineNumber = lineNumber + 1;
          else
            chemEntryArray = addChemEntry(lineNumber, fileName{i}, cleanLine, chemEntryArray);
            lineNumber = lineNumber + 1;
          end
        end
        % close ".chem" file
        fclose(fileID);
      end
      
    end

    function gasAndValueArray = gasPropertyFile(fileName)
    % gasPropertyFile Reads a file with gas properties, parse its content
    % and returns an structure array 'gasAndValueArray' with all the
    % information.
    
      regExp = '(?<gasName>\w+)\s*(?<valueStr>.+)';
      fileID = fopen([Parse.inputFolder filesep fileName], 'r');
      if fileID == -1
        error('\t Unable to open file: %s\n', [Parse.inputFolder filesep fileName]);
      end
      
      gasAndValueArray = struct.empty;
      while ~feof(fileID)
        line = removeComments(fgetl(fileID));
        if isempty(line)
          continue
        end
        gasProperty = regexp(line, regExp, 'names', 'once');
        if ~isempty(gasProperty)
          gasAndValueArray(end+1).gasName = gasProperty.gasName;
          gasAndValueArray(end).value = str2num(gasProperty.valueStr);
        end
      end
      
      fclose(fileID);
      
    end
    
    function parsedEntry = gasPropertyEntry(entry)
    % gasPropertyEntry parses an entry (string) of the input file that
    % contains information related to a certain gas property. It returns an
    % structure with the parsed information. 
    
      regExp = ['(?<gasName>\w+)\s*=\s*(?<constant>[\d.eE\s()*/+-]+)?' ...
        '(?<function>\w+)?(?(function)@?)(?<argument>.+)?\s*'];
      parsedEntry = regexp(entry, regExp, 'names');
      if isempty(parsedEntry)
        parsedEntry = struct('fileName', entry);
      elseif ~isempty(parsedEntry.function)
        if ~isempty(parsedEntry.constant)
          error(['Error found when parsing state property entry:\n%s\n' ...
            'Please, fix the problem and run the code again'], entry);
        end
        if isempty(parsedEntry.argument)
          parsedEntry.argument = cell(0);
        else
          parsedEntry.argument = strsplit(parsedEntry.argument, ',');
          for i=1:length(parsedEntry.argument)
            numericArgument = str2num(parsedEntry.argument{i});
            if ~isnan(numericArgument)
              parsedEntry.argument{i} = numericArgument;
            end
          end
        end
      else
        parsedEntry.constant = str2num(parsedEntry.constant);
      end
      
    end
    
    function stateAndValueArray = statePropertyFile(fileName)
    % statePropertyFile Reads a file with state properties, parse its
    % content and returns an structure array 'stateAndValueArray' with all
    % the information.
    
      regExp = [Parse.stateRegExp '\s*(?<valueStr>.+)'];
      fileID = fopen([Parse.inputFolder filesep fileName], 'r');
      if fileID == -1
        error('\t Unable to open file: %s\n', [Parse.inputFolder filesep fileName]);
      end
      
      stateAndValueArray = struct.empty;
      while ~feof(fileID)
        line = removeComments(fgetl(fileID));
        if isempty(line)
          continue
        end
        stateProperty = regexp(line, regExp, 'names', 'once');
        if ~isempty(stateProperty)
          stateAndValueArray(end+1).gasName = stateProperty.gasName;
          stateAndValueArray(end).ionCharg = stateProperty.ionCharg;
          stateAndValueArray(end).eleLevel = stateProperty.eleLevel;
          stateAndValueArray(end).vibLevel = stateProperty.vibLevel;
          stateAndValueArray(end).rotLevel = stateProperty.rotLevel;
          stateAndValueArray(end).value = str2num(stateProperty.valueStr);
        end
      end
      
    end
    
    function parsedEntry = statePropertyEntry(entry)
    % statePropertyEntry parses an entry (string) of the input file that
    % contains information related to a certain state property. It returns
    % an structure with the parsed information. 
    
      regExp = [Parse.stateRegExp '\s*=\s*(?<constant>[\d.eE\s()*/+-]+)?' ...
        '(?<function>\w+)?(?(function)@?)(?<argument>.+)?\s*'];
      parsedEntry = regexp(entry, regExp, 'names');
      if isempty(parsedEntry)
        parsedEntry = struct('fileName', entry);
      elseif ~isempty(parsedEntry.function)
        if ~isempty(parsedEntry.constant)
          error(['Error found when parsing state property entry:\n%s\n' ...
            'Please, fix the problem and run the code again'], entry);
        end
        if isempty(parsedEntry.argument)
          parsedEntry.argument = cell(0);
        else
          parsedEntry.argument = strsplit(parsedEntry.argument, ',');
          for i=1:length(parsedEntry.argument)
            numericArgument = str2num(parsedEntry.argument{i});
            if ~isnan(numericArgument)
              parsedEntry.argument{i} = numericArgument;
            end
          end
        end
      else
        parsedEntry.constant = str2num(parsedEntry.constant);
      end
      
    end
    
  end
  
end

function [structArray, rawLine] = file2structArray(file)
% file2structArray Reads an input file and and creates an array of input
% structs with all the information.
%
% See also structArray2struct
      
  fileID = fopen(file, 'r');
  if fileID == -1
    error('\t Unable to open file: %s\n', file);
  end
  structArray = struct.empty;
  rawLine = cell.empty;
  while ~feof(fileID)
    rawLine{end+1} = removeComments(fgetl(fileID));
    line = strtrim(rawLine{end});
    if isempty(line)
      rawLine = rawLine(1:end-1);
      continue;
    elseif strncmp(line, '-', 1)
      structArray(end).value{end+1} = str2value(line(2:end));
    else
      nameAndValue=strtrim(strsplit(line,':'));
      structArray(end+1).name = nameAndValue{1};
      structArray(end).value = str2value(nameAndValue{2});
      structArray(end).level = regexp(rawLine{end}, '\S', 'once');
    end
  end
  fclose(fileID);
      
end

function structure = structArray2struct(structArray)
% structArray2struct Convert an array of structures into a single structure.
%
% See also file2structArray
    
  i = 1;
  iMax = length(structArray);
  while i<=iMax
    if (i<iMax && structArray(i).level<structArray(i+1).level)
      counter = 1;
      for j = i+2:iMax
        if (structArray(j).level>structArray(i).level)
          counter = counter+1;
        else
          break
        end
      end
      structure.(structArray(i).name) = ...
        structArray2struct(structArray(i+1:i+counter));
      i = i+counter+1;
    else
      structure.(structArray(i).name) = structArray(i).value;
      i = i+1;
    end
  end
      
end

function textLineClean = removeComments(textLine)
% removeComments Return a string without comments.
%
% Comment delimiter is defined in the property commentChar of the Parse class.
% Note: Comment symbol is NOT ignored even if it's inside a string.
  
  idx = regexp(textLine, Parse.commentChar, 'once'); 
  if isempty(idx)
    textLineClean = textLine;
  else
    textLineClean = textLine(1:idx-1);
  end
end

function value = str2value(str)
% str2value Converts a string to a value. Posible values are: numeric,
% logical or string

  [value, is_number_or_logical] = str2num(strtrim(str));
  if ~is_number_or_logical
    value = strtrim(str);
  end
      
end

function LXCatEntryArray = addLXCatEntry(description, parameter, rawCrossSection, LXCatEntryArray)
% addLXCatEntry analyses the information of a particular LXCat entry and adds it to the structure array
% LXCatEntryArray.
      
  LXCatEntryArray(end+1).type = description.type;
  if isempty(description.subtype)
    LXCatEntryArray(end).isMomentumTransfer = false;
  else
    LXCatEntryArray(end).isMomentumTransfer = true;
  end
  if strcmp(description.direction, '->')
    LXCatEntryArray(end).isReverse = false;
  elseif strcmp(description.direction, '<->')
    LXCatEntryArray(end).isReverse = true;
  end
  LXCatEntryArray(end).target = regexp(description.reactants, Parse.stateRegExp, 'names', 'once');
  if isempty(LXCatEntryArray(end).target)
    error(['I can not find a target in the collision:\n%s\nthat match the regular expression for a state.\n'...
      'Please check your LXCat files'], [description.reactants description.direction description.products]);
  end
  electronArray = regexp(description.reactants, Parse.electronRegExp, 'names');
  numElectrons = 0;
  for i = 1:length(electronArray)
    if isempty(electronArray(i).quantity)
      numElectrons = numElectrons+1;
    else
      numElectrons = numElectrons+str2double(electronArray(i).quantity);
    end
  end
  LXCatEntryArray(end).reactantElectrons = numElectrons;
  productArray = regexp(description.products, Parse.stateRegExp, 'names');
  LXCatEntryArray(end).productArray = removeDuplicatedStates(productArray);
  if isempty(LXCatEntryArray(end).productArray)
    error(['I can not find a product in the collision:\n%s\nthat match the regular expression for a state.\n'...
      'Please check your LXCat files'], [description.reactants description.direction description.products]);
  end
  electronArray = regexp(description.products, Parse.electronRegExp, 'names');
  numElectrons = 0;
  for i = 1:length(electronArray)
    if isempty(electronArray(i).quantity)
      numElectrons = numElectrons+1;
    else
      numElectrons = numElectrons+str2double(electronArray(i).quantity);
    end
  end
  LXCatEntryArray(end).productElectrons = numElectrons;
  if isempty(parameter)
    LXCatEntryArray(end).threshold = 0;
  else
    threshold = str2double(parameter.threshold);
    if isnan(threshold) 
      error('I can not properly parse ''%s'' as the threshold of reaction ''%s''.\nPlease check your LXCat files', ...
        parameter.threshold, [description.reactants description.direction description.products]);
    elseif threshold<0
      error('Reaction ''%s'' has a negative threshold (''%s'').\nPlease check your LXCat files', ...
        [description.reactants description.direction description.products], parameter.threshold);
    end
    LXCatEntryArray(end).threshold = threshold;
  end
  LXCatEntryArray(end).rawCrossSection = rawCrossSection;
  
end

function chemEntryArray = addChemEntry(lineNumber, fileName, cleanLine, chemEntryArray)

  % definition of regular expressions to parse chemistry entries
  chemRegExp = ['\s*(?<reactants>.*?)\s*(?<direction>->|<->)\s*(?<products>.*?)'...
    '\s*[|]\s*(?<type>\w+)\s*[|]\s*(?<parameters>.*?)[|](?<enthalpy>.*)'];
  stateRegExp = ['\s*(?<quantity>[\d.]+\s*)?(?<gasName>\w+)\((?<ionCharg>[-+])?'...
    ',?(?<eleLevel>[\w][\w''.\[\]/+*-]*)'...
    ',?(?<vibRange>(?<=,)[vw](?==))?=?(?<vibLevel>(?<=,[vw]=)[vw\d:+*-]+)?'...
    '(?:,J=)?(?<rotLevel>(?<=,J=)[\d+*-]+)?\)\s*'];
  electronRegExp = '\s*(?<quantity>\d+)?((?:[eE]\s*)(?=[\s]|[+][^\(])|(?:[eE]$))';
  wallRegExp = '\s*(?<gasName>[wW][aA][lL][lL])\s*';
  gasRegExp = '\s*(?<gasName>[gG][aA][sS])\s*';
  
  % parsing chemistry entry to check for proper structure
  auxChemEntry = regexp(cleanLine, chemRegExp, 'names', 'once');
  if isempty(auxChemEntry)
    error(['Error when parsing line %d of file %s:\n%s\nChemistry entries should follow the struture:\n' ...
      '<reactants> [<]-> <products> | <rate coefficient type> | [rate coefficient function parameters] | ' ...
      '[reaction enthalpy]'], lineNumber, fileName, cleanLine);
  elseif isempty(auxChemEntry.reactants)
    error(['Error when parsing line %d of file %s:\n%s\nChemistry entries should follow the struture:\n' ...
      '<reactants> [<]-> <products> | <rate coefficient type> | [rate coefficient function parameters] | ' ...
      '[reaction enthalpy]'], lineNumber, fileName, cleanLine);
  elseif isempty(auxChemEntry.products)
    error(['Error when parsing line %d of file %s:\n%s\nChemistry entries should follow the struture:\n' ...
      '<reactants> [<]-> <products> | <rate coefficient type> | [rate coefficient function parameters] | ' ...
      '[reaction enthalpy]'], lineNumber, fileName, cleanLine);
  end
  
  % initialize variables
  reactantArray = struct.empty;
  reactantElectrons = 0;
  productArray = struct.empty;
  productElectrons = 0;
  isTransport = false;
  leftHandSideGas = false;
  rightHandSideGas = false;
  isGasStabilised = false;
  
  % parsing species on the left hand side of the reaction
  rawReactants = regexp(auxChemEntry.reactants, [stateRegExp '|' electronRegExp '|' wallRegExp '|' gasRegExp], 'names');
  % checking proper writing of the left hand side of the reaction
  pluses = regexp(auxChemEntry.reactants, [stateRegExp '|' electronRegExp '|' wallRegExp '|' gasRegExp], 'split');
  if ~strcmp(pluses{1}, '') || ~strcmp(pluses{end}, '')
    error('Error when parsing line %d of file %s:\n %s\n Please check the reactants of the reaction description.', ...
      lineNumber, fileName, cleanLine);
  end
  for i = 2:length(pluses)-1
    if ~strcmp(pluses{i}, '+')
      error('Error when parsing line %d of file %s:\n %s\n Please check the reactants of the reaction description.', ...
        lineNumber, fileName, cleanLine);
    end
  end
  % parsing electrons, wall, gas or regular reactants (states)
  for i = 1:length(rawReactants)
    if isempty(rawReactants(i).gasName)
      if isempty(rawReactants(i).quantity)
        reactantElectrons = reactantElectrons+1;
      else
        reactantElectrons = reactantElectrons+str2double(rawReactants(i).quantity);
      end
    elseif length(rawReactants(i).gasName)>=4 && strcmpi(rawReactants(i).gasName(1:4), 'wall')
      for j = 1:length(rawReactants)
        if i==j
          continue;
        elseif ~(length(rawReactants(j).gasName)>=4 && strcmpi(rawReactants(j).gasName(1:4), 'wall'))
          isTransport = true;
        end
      end
      if ~strcmpi(rawReactants(i).gasName, 'wall')
        if isempty(reactantArray)
          reactantArray = rawReactants(i);
        else
          reactantArray(end+1) = rawReactants(i);
        end
      end
    elseif strcmpi(rawReactants(i).gasName, 'gas')
      if leftHandSideGas
        error(['Error when parsing line %d of file %s:\n %s\nThe simulation can not have more than one "gas" ' ...
          'on the left hand side.'], lineNumber, fileName, cleanLine);
      end
      leftHandSideGas = true;
    else
      if isempty(reactantArray)
        reactantArray = rawReactants(i);
      else
        reactantArray(end+1) = rawReactants(i);
      end
    end
  end
  
  % parsing species on the right hand side of the reaction 
  rawProducts = regexp(auxChemEntry.products, [stateRegExp '|' electronRegExp '|' wallRegExp '|' gasRegExp], 'names');
  % checking proper writing of the right hand side of the reaction
  pluses = regexp(auxChemEntry.products, [stateRegExp '|' electronRegExp '|' wallRegExp '|' gasRegExp], 'split');
  if ~strcmp(pluses{1}, '') || ~strcmp(pluses{end}, '')
    error('Error when parsing line %d of file %s:\n %s\n Please check the products of the reaction description.', ...
      lineNumber, fileName, cleanLine);
  end
  for i = 2:length(pluses)-1
    if ~strcmp(pluses{i}, '+')
      error('Error when parsing line %d of file %s:\n %s\n Please check the products of the reaction description.', ...
        lineNumber, fileName, cleanLine);
    end
  end
  % parsing electrons, gas or regular products (states)
  for i = 1:length(rawProducts)
    if isempty(rawProducts(i).gasName)
      if isempty(rawProducts(i).quantity)
        productElectrons = productElectrons+1;
      else
        productElectrons = productElectrons+str2double(rawProducts(i).quantity);
      end
    elseif strcmpi(rawProducts(i).gasName, 'wall')
      error('Error when parsing line %d of file %s:\n %s\nThe simulation can not create "wall".', ...
        lineNumber, fileName, cleanLine);
    elseif strcmpi(rawProducts(i).gasName, 'gas')
      if rightHandSideGas
        error(['Error when parsing line %d of file %s:\n %s\nThe simulation can not have more than one "gas" ' ...
          'on the right hand side.'], lineNumber, fileName, cleanLine);
      end
      rightHandSideGas = true;
    else
      if isempty(productArray)
        productArray = rawProducts(i);
      else
        productArray(end+1) = rawProducts(i);
      end
    end
  end
  
  % check if the reaction is stabilised by the gas, i.e. it includes a gas molecule (any) as catalyst
  if leftHandSideGas && rightHandSideGas
    isGasStabilised = true;
  elseif leftHandSideGas
    error('Error when parsing line %d of file %s:\n %s\nThe simulation can not destroy "gas".', ...
      lineNumber, fileName, cleanLine);
  elseif rightHandSideGas
    error('Error when parsing line %d of file %s:\n %s\nThe simulation can not create "gas".', ...
      lineNumber, fileName, cleanLine);
  end
  
  % analyse the directionality of the reaction 
  if strcmp(auxChemEntry.direction, '->')
    isReverse = false;
  else
    isReverse = true;
  end
  
  % parsing rate coefficient parameters
  rawRateCoeffParams = regexp(auxChemEntry.parameters, ',', 'split');
  rateCoeffParams = cell(size(rawRateCoeffParams));
  for i = 1:length(rawRateCoeffParams)
    rateCoeffParams{i} = str2value(rawRateCoeffParams{i});
  end
  
  % parsing reaction enthalpy
  enthalpy = str2value(auxChemEntry.enthalpy);
  
  % analise vibrational ranges
  vRangeReactantID = [];
  vRange = [];
  vDependentProductIDs = [];
  vDependentExpression = {};
  wRangeReactantID = [];
  wRange = [];
  wDependentProductIDs = [];
  wDependentExpression = {};
  for i = 1:length(reactantArray)
    if ~isempty(reactantArray(i).vibLevel) && ~isempty(strfind(reactantArray(i).vibLevel, ':'))
      switch reactantArray(i).vibRange
        case 'v'
          if ~isempty(vRange)
            error('vRange already filled up');
          end
          vRangeReactantID = i;
          vRange = reactantArray(i).vibLevel;
          for j = 1:length(productArray)
            if ~isempty(strfind(productArray(j).vibLevel, 'v'))
              vDependentProductIDs(end+1) = j;
              vDependentExpression{end+1} = productArray(j).vibLevel;
            end
          end
        case 'w'
          if ~isempty(wRange)
            error('wRange already filled up');
          end
          wRangeReactantID = i;
          wRange = reactantArray(i).vibLevel;
          for j = 1:length(productArray)
            if ~isempty(strfind(productArray(j).vibLevel, 'w'))
              wDependentProductIDs(end+1) = j;
              wDependentExpression{end+1} = productArray(j).vibLevel;
            end
          end
      end
    end
  end
  
  % add new reactions
  newChemEntry.type = auxChemEntry.type;
  newChemEntry.isTransport = isTransport;
  newChemEntry.isGasStabilised = isGasStabilised;
  newChemEntry.isReverse = isReverse;
  newChemEntry.rateCoeffParams = rateCoeffParams;
  newChemEntry.enthalpy = enthalpy;
  newChemEntry.reactantElectrons = reactantElectrons;
  newChemEntry.productElectrons = productElectrons;
  if isempty(vRange) && isempty(wRange)
    % removing duplicated states in the reactant array
    newReactantArray = removeDuplicatedStates(reactantArray);
    % removing duplicated states in the product array
    newProductArray = removeDuplicatedStates(productArray);
    % find catalyst species in the reaction
    [newReactantArray, newProductArray, catalystArray] = findCatalysts(newReactantArray, newProductArray);
    % avoid reactions where nothing is created nor destroyed
    if isempty(newReactantArray) && isempty(newProductArray)
      return;
    end
    % saving new chemistry entry
    newChemEntry.reactantArray = newReactantArray;
    newChemEntry.productArray = newProductArray;
    newChemEntry.catalystArray = catalystArray;
    if isempty(chemEntryArray)
      chemEntryArray = newChemEntry;
    else
      chemEntryArray(end+1) = newChemEntry;
    end
  elseif isempty(vRange)
    for w = eval(wRange)
      % evaluating reactant states
      reactantArray(wRangeReactantID).vibLevel = int2str(w);
      % evaluating product states
      for j = 1:length(wDependentProductIDs)
        productArray(wDependentProductIDs(j)).vibLevel = int2str(eval(wDependentExpression{j}));
      end
      % removing duplicated states in the reactant array
      newReactantArray = removeDuplicatedStates(reactantArray);
      % removing duplicated states in the product array
      newProductArray = removeDuplicatedStates(productArray);
      % find catalyst species in the reaction
      [newReactantArray, newProductArray, catalystArray] = findCatalysts(newReactantArray, newProductArray);
      % avoid reactions where nothing is created nor destroyed
      if isempty(newReactantArray) && isempty(newProductArray)
        continue;
      end
      % saving new chemistry entry
      newChemEntry.reactantArray = newReactantArray;
      newChemEntry.productArray = newProductArray;
      newChemEntry.catalystArray = catalystArray;
      if isempty(chemEntryArray)
        chemEntryArray = newChemEntry;
      else
        chemEntryArray(end+1) = newChemEntry;
      end
    end
  elseif isempty(wRange)
    for v = eval(vRange)
      % evaluating reactant states
      reactantArray(vRangeReactantID).vibLevel = int2str(v);
      % evaluating product states
      for j = 1:length(vDependentProductIDs)
        productArray(vDependentProductIDs(j)).vibLevel = int2str(eval(vDependentExpression{j}));
      end
      % removing duplicated states in the reactant array
      newReactantArray = removeDuplicatedStates(reactantArray);
      % removing duplicated states in the product array
      newProductArray = removeDuplicatedStates(productArray);
      % find catalyst species in the reaction
      [newReactantArray, newProductArray, catalystArray] = findCatalysts(newReactantArray, newProductArray);
      % avoid reactions where nothing is created nor destroyed
      if isempty(newReactantArray) && isempty(newProductArray)
        continue;
      end
      % saving new chemistry entry
      newChemEntry.reactantArray = newReactantArray;
      newChemEntry.productArray = newProductArray;
      newChemEntry.catalystArray = catalystArray;
      if isempty(chemEntryArray)
        chemEntryArray = newChemEntry;
      else
        chemEntryArray(end+1) = newChemEntry;
      end
    end
  else
    for v = eval(vRange)
      % evaluating reactant states (v)
      reactantArray(vRangeReactantID).vibLevel = int2str(v);
      % evaluating product states (v)
      for j = 1:length(vDependentProductIDs)
        productArray(vDependentProductIDs(j)).vibLevel = int2str(eval(vDependentExpression{j}));
      end
      for w = eval(wRange)
        % evaluating reactant states (w)
        reactantArray(wRangeReactantID).vibLevel = int2str(w);
        % evaluating product states (w)
        for j = 1:length(wDependentProductIDs)
          productArray(wDependentProductIDs(j)).vibLevel = int2str(eval(wDependentExpression{j}));
        end
        % removing duplicated states in the reactant array
        newReactantArray = removeDuplicatedStates(reactantArray);
        % removing duplicated states in the product array
        newProductArray = removeDuplicatedStates(productArray);
        % find catalyst species in the reaction
        [newReactantArray, newProductArray, catalystArray] = findCatalysts(newReactantArray, newProductArray);
        % avoid reactions where nothing is created nor destroyed
        if isempty(newReactantArray) && isempty(newProductArray)
          continue;
        end
        % saving new chemistry entry
        newChemEntry.reactantArray = newReactantArray;
        newChemEntry.productArray = newProductArray;
        newChemEntry.catalystArray = catalystArray;
        if isempty(chemEntryArray)
          chemEntryArray = newChemEntry;
        else
          chemEntryArray(end+1) = newChemEntry;
        end
      end
    end
  end
  
end

function newStateArray = removeDuplicatedStates(stateArray)
  
  if isempty(stateArray)
    newStateArray = struct.empty;
    return
  end
  
  numStates = length(stateArray);
  newStateArray = stateArray(1);
  if isempty(newStateArray.quantity)
    newStateArray.quantity = 1;
  else
    newStateArray.quantity = str2double(newStateArray.quantity);
  end
  for i = 2:numStates
    for j = 1:length(newStateArray)
      if strcmp(stateArray(i).gasName, newStateArray(j).gasName) && ...
          strcmp(stateArray(i).ionCharg, newStateArray(j).ionCharg) && ...
          strcmp(stateArray(i).eleLevel, newStateArray(j).eleLevel) && ...
          strcmp(stateArray(i).vibLevel, newStateArray(j).vibLevel) && ...
          strcmp(stateArray(i).rotLevel, newStateArray(j).rotLevel)
        if isempty(stateArray(i).quantity)
          newStateArray(j).quantity = newStateArray(j).quantity+1;
        else
          newStateArray(j).quantity = newStateArray(j).quantity+str2double(stateArray(i).quantity);
        end
        break;
      end
      if j == length(newStateArray)
        newStateArray(end+1) = stateArray(i);
        if isempty(stateArray(i).quantity)
          newStateArray(end).quantity = 1;
        else
          newStateArray(end).quantity = str2double(stateArray(i).quantity);
        end
      end
    end
  end
  
end

function [reactantArray, productArray, catalystArray] = findCatalysts(reactantArray, productArray)
  catalystArray = [];
  i = 1;
  while i <= length(reactantArray)
    j = 1;
    while j <= length(productArray)
      if strcmp(reactantArray(i).gasName, productArray(j).gasName) && ...
          strcmp(reactantArray(i).ionCharg, productArray(j).ionCharg) && ...
          strcmp(reactantArray(i).eleLevel, productArray(j).eleLevel) && ...
          strcmp(reactantArray(i).vibLevel, productArray(j).vibLevel) && ...
          strcmp(reactantArray(i).rotLevel, productArray(j).rotLevel)
        if isempty(catalystArray)
          catalystArray = reactantArray(i);
        else
          catalystArray(end+1) = reactantArray(i);
        end
        if reactantArray(i).quantity < productArray(j).quantity
          productArray(j).quantity = productArray(j).quantity-reactantArray(i).quantity;
          reactantArray = reactantArray([1:i-1 i+1:end]);
          i = i-1;
          break;
        elseif reactantArray(i).quantity > productArray(j).quantity
          catalystArray(end).quantity = productArray(j).quantity;
          reactantArray(i).quantity = reactantArray(i).quantity-productArray(j).quantity;
          productArray = productArray([1:j-1 j+1:end]);
          break;
        else
          reactantArray = reactantArray([1:i-1 i+1:end]);
          i = i-1;
          productArray = productArray([1:j-1 j+1:end]);
          break;
        end
      end
      j = j+1;
    end
    i = i+1;
  end
end
