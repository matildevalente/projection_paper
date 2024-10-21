function [rateCoeff, dependent] = powerTemp(~, ~, ~, ~, ~, ~, ~, ~, rateCoeffParams)
% powerTemp evaluates a reaction rate coefficients using the following expression:

  T = rateCoeffParams{1};
  a = rateCoeffParams{2};
  b = rateCoeffParams{3};

  rateCoeff = a * T^b;
  
  % set function dependencies
  dependent = struct('onTime', false, 'onDensities', false, 'onGasTemperature', false, 'onElectronKinetics', false);

end