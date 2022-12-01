function f = matRad_objectiveFunction(optiProb,apertureInfoVec,dij,cst)
% matRad IPOPT callback: objective function for direct aperture optimization
%
% call
%   f = matRad_objectiveFunction(optiProb,apertureInfoVect,dij,cst)  
%
% input
%   optiProb:           option struct defining the type of optimization
%   apertureInfoVec:   aperture info in form of vector
%   dij:                matRad dij struct as generated by bixel-based dose calculation
%   cst:                matRad cst struct
%
% output
%   f: objective function value
%
% References
%   [1] http://dx.doi.org/10.1118/1.4914863
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Copyright 2015 the matRad development team. 
% 
% This file is part of the matRad project. It is subject to the license 
% terms in the LICENSE file found in the top-level directory of this 
% distribution and at https://github.com/e0404/matRad/LICENSES.txt. No part 
% of the matRad project, including this file, may be copied, modified, 
% propagated, or distributed except according to the terms contained in the 
% LICENSE file.
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% update apertureInfo, bixel weight vector an mapping of leafes to bixels
if ~isequal(apertureInfoVec,optiProb.apertureInfo.apertureVector)
    optiProb.apertureInfo = optiProb.matRad_daoVec2ApertureInfo(optiProb.apertureInfo,apertureInfoVec);
end
apertureInfo = optiProb.apertureInfo;

% bixel based objective function calculation
f = matRad_objectiveFunction@matRad_OptimizationProblem(optiProb,apertureInfo.bixelWeights,dij,cst);
