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
  
function lokibcl(setupFile)
  
  % ----- CLEARING PREVIOUSLY USED IDs AND CLOSING PREVIOUSLY OPEN FIGURES -----
  
  save setupFile
  clear all
  load setupFile
  delete setupFile.mat
  close all
  
  % ----- CREATING SETUP OBJECT -----
  
  setup = Setup(setupFile);
  
  % ----- INITIALIZING SIMULATION -----
  
  electronKinetics = setup.initializeSimulation();
  
  % ----- MAIN BODY OF THE SIMULATION -----
  
  % loop over the different jobs specified in the setup
  while setup.currentJobID <= setup.numberOfJobs
  
    % --- run a particular job (obtain an eedf)
    electronKinetics.solve();
    
    % --- set up next job
    setup.nextJob();
    
  end
  
  % ----- FINISHING SIMULATION -----
  
  setup.finishSimulation();
  
end
