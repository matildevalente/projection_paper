function [rateCoeff, dependent] = binaryTransport(~, ~, totalGasDensity, reactionArray, reactionID, ...
  stateArray, workCond, ~, rateCoeffParams)
  % binaryTransport evaluates the transport rate coefficient of a particular species interacting with the wall, 
  % taking into account both the binary diffusion time and the wall reaction time assuming a
  % flux reaching the wall (with a certain wall recombination/deactivation probability).
  % 
  % For more info check documentation.

  persistent firstBesselZero;
  persistent gammaSumArray;
  persistent dependentInfo;
  
  % local save of the ID of the reactant species
  reactantID = reactionArray(reactionID).reactantArray(1).ID;
  
  % --- performance sensitive calculations ---
  
  % calculations performed once per simulation 
  if isempty(dependentInfo)
    % evaluate the first zero of the zero order bessel function
    firstBesselZero = fzero(@(x) besselj(0,x), [2.4 2.5]);
    % define dependencies of the rate coefficient
    dependentInfo = struct('onTime', false, 'onDensities', true, 'onGasTemperature', true, 'onElectronKinetics', false);
    % initialize array of gammaSum (total loss wall probability)
    gammaSumArray = zeros(size(stateArray));
  end
  
  % evaluate total wall reaction probability for the reactant specie (only done once per lost species)
  if gammaSumArray(reactantID) == 0
    % evaluate total wall reaction coefficient
    for reaction = stateArray(reactantID).reactionsDestruction
      if reaction.isTransport
        if strcmp(reaction.type, reactionArray(reactionID).type)
          if ~isempty(reaction.rateCoeffParams) && ...
              isnumeric(reaction.rateCoeffParams{1}) && reaction.rateCoeffParams{1}<=1 && reaction.rateCoeffParams{1}>0
            gammaSumArray(reactantID) = gammaSumArray(reactantID) + reaction.rateCoeffParams{1};
          else % error checking
            error(['Error found when evaluating ''%s'' rate coefficient for reaction:\n%s.\n''wallCoefficient'' ' ...
              'not probided (or wrong value) in the corresponding ''.chem'' file.\nPlease, fix the problem and ' ...
              'run the code again'], reaction.type, reaction.description);
          end
        else % error checking
          error(['Error found when evaluating ''%s'' rate coefficient for reaction:\n%s.\n' ...
            'It has been found another transport reaction of a different type for the same species:\n%s.\nPlease, ' ...
            'fix the problem and run the code again'], reactionArray(reactionID).type, ...
            reactionArray(reactionID).description, reaction.description);
        end
      end
    end
    % error checking for limiting values of gammaSumArray
    if gammaSumArray(reactantID) == 0
      error(['Error found when evaluating ''%s'' rate coefficient for reaction:\n%s.\n' ...
        'Total wall reaction probability must be different than zero.\nPlease, fix the problem and run the code ' ...
        'again'], reactionArray(reactionID).type, reactionArray(reactionID).description, reaction.description);
    elseif gammaSumArray(reactantID) > 1
      error(['Error found when evaluating ''%s'' rate coefficient for reaction:\n%s.\n' ...
        'Total wall reaction probability can not be larger than 1.\nPlease, fix the problem and run the code ' ...
        'again'], reactionArray(reactionID).type, reactionArray(reactionID).description, reaction.description);
    end
  end

  % --- regular calculations ---
  
  % evaluate thermal velocity
  temperatureStr = rateCoeffParams{2};
  if ~any(strcmp(temperatureStr, {'gasTemperature' 'nearWallTemperature' 'wallTemperature'}))
    error(['Error found when evaluating ''%s'' rate coefficient for reaction:\n%s.\n''%s'' is not a valid temperature ' ...
      'to evaluate the thermal velocity with.\nChoose one of the following: ''gasTemperature'', ''nearWallTemperature'' ' ...
      'or ''wallTemperature''.\nPlease, fix the problem and run the code again'], reactionArray(reactionID).type, ...
      reactionArray(reactionID).description, rateCoeffParams{2});
  elseif isempty(workCond.(temperatureStr))
    error(['Error found when evaluating ''%s'' rate coefficient for reaction:\n%s.\n''%s'' not found in the working ' ...
      'conditions object.\nPlease, fix the problem and run the code again'], reactionArray(reactionID).type, ...
      reactionArray(reactionID).description, rateCoeffParams{2});
  else
    thermalVelocity = sqrt(8*Constant.boltzmann*workCond.(temperatureStr)/(pi*stateArray(reactantID).gas.mass));
  end
  
  % evaluate diffusion rate coefficient
  redDiffCoeff = reactionArray(reactionID).reactantArray(1).evaluateReducedDiffCoeff(workCond);
  % evaluate aux variable
  aux = thermalVelocity*gammaSumArray(reactantID)/((redDiffCoeff/totalGasDensity)*4*(1-gammaSumArray(reactantID)/2));
  
  % evaluate effective diffusion length for a cylinder (including infinitely long cylinder and slab limiting cases)
  L = workCond.chamberLength;
  R = workCond.chamberRadius;
  if L == 0        % infinitely long cylinder
    squaredEffectiveDiffusionLength = ( R / ...
      fzero(@(x) aux-besselj(1,x)*x/(besselj(0,x)*R), [0 firstBesselZero-eps(firstBesselZero)]) )^2;
  elseif R == 0    % infinitely wide cylinder (slab)
    squaredEffectiveDiffusionLength = ( L / (2*...
      fzero(@(x) aux-tan(x)*x*2/L, [0 pi/2-eps(pi/2)])) )^2;
  else             % finite cylinder
    squaredEffectiveDiffusionLength = 1 / ( ... 
      (fzero(@(x) aux-besselj(1,x)*x/(besselj(0,x)*R), [0 firstBesselZero-eps(firstBesselZero)])/R)^2 + ...
      (fzero(@(x) aux-tan(x)*x*2/L, [0 pi/2-eps(pi/2)])*2/L)^2 );
  end
  
  % evaluate wall reaction coefficient
  gamma = rateCoeffParams{1};
  % evaluate rate coefficient
  rateCoeff = (gamma/gammaSumArray(reactantID))*(redDiffCoeff/(totalGasDensity*squaredEffectiveDiffusionLength));

  % set function dependencies
  dependent = dependentInfo;
  if ~dependent.onGasTemperature && ~isempty(reactionArray(reactionID).reactantArray(1).reducedDiffCoeffFunc)
    for param = reactionArray(reactionID).reactantArray(1).reducedDiffCoeffParams
      if strcmp(param{1}, 'gasTemperature')
        dependent.onGasTemperature = true;
      end
    end
  end

end
