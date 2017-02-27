function updatedInfo = matRad_daoVec2ApertureInfo(apertureInfo,apertureInfoVect,touchingFlag)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% matRad function to translate the vector representation of the aperture
% shape and weight into an aperture info struct. At the same time, the
% updated bixel weight vector w is computed and a vector listing the
% correspondence between leaf tips and bixel indices for gradient
% calculation
%
% call
%   updatedInfo = matRad_daoVec2ApertureInfo(apertureInfo,apertureInfoVect)
%
% input
%   apertureInfo:     aperture shape info struct
%   apertureInfoVect: aperture weights and shapes parameterized as vector
%   touchingFlag:     if this is one, clean up instances of leaf touching,
%                     otherwise, do not
%
% output
%   updatedInfo: updated aperture shape info struct according to apertureInfoVect
%
% References
%
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

if nargin < 3
    touchingFlag = 0; %default is 0, it should really only be 1 when called the first time in the leaf sequencing function, never during DAO
end

% function to update the apertureInfo struct after the each iteraton of the
% optimization

w = zeros(apertureInfo.totalNumOfBixels,1);

% initializing variables
updatedInfo = apertureInfo;

updatedInfo.apertureVector = apertureInfoVect;

shapeInd = 1;

%indVect = NaN*ones(size(apertureInfoVect));

%change this to eliminate the first unused entries (which pertain to the
%weights of the aprtures, and to make the bixelIndices work when doing VMAT
%(and we need to potentially interpolate between control points)
indVect = NaN*ones(2*apertureInfo.realTotalNumOfLeafPairs,1);
offset = 0;

% helper function to cope with numerical instabilities through rounding
round2 = @(a,b) round(a*10^b)/10^b;


%% update the shapeMaps
% here the new colimator positions are used to create new shapeMaps that
% now include decimal values instead of binary

% loop over all beams
for i = 1:numel(updatedInfo.beam)
    
    %posOfRightCornerPixel = apertureInfo.beam(i).posOfCornerBixel(1) + (size(apertureInfo.beam(i).bixelIndMap,2)-1)*apertureInfo.bixelWidth;
    
    % pre compute left and right bixel edges
    edges_l = updatedInfo.beam(i).posOfCornerBixel(1)...
        + ([1:size(apertureInfo.beam(i).bixelIndMap,2)]-1-1/2)*updatedInfo.bixelWidth;
    edges_r = updatedInfo.beam(i).posOfCornerBixel(1)...
        + ([1:size(apertureInfo.beam(i).bixelIndMap,2)]-1+1/2)*updatedInfo.bixelWidth;
    
    if updatedInfo.beam(i).numOfShapes ~= 0 %numOfShapes is 0 for interpolated beams!
        
        %This should only occur for VMAT subchildren angles, i.e., not
        %independently optimized
        %Interpolate this segment between adjacent optimized gantry angles.
        % Include in updatedInfo, but NOT the vector (since these are not
        % optimized by DAO).  Also update bixel weights to include these.
        if ~exist('leftLeafPoss','var') && isfield(apertureInfo,'gantryRotCst')
            
            %Only collect this data once, to save time
            dimZ = updatedInfo.beam(1).numOfActiveLeafPairs;
            leftLeafPoss = nan(dimZ,updatedInfo.totalNumOfShapes); %Each non-interpolated beam should have 1 and only 1 shape
            rightLeafPoss = nan(dimZ,updatedInfo.totalNumOfShapes);
            optWeights = zeros(1,updatedInfo.totalNumOfShapes);
            nextOptTime = zeros(1,updatedInfo.totalNumOfShapes-1);
            optGantryAngles = zeros(1,updatedInfo.totalNumOfShapes);
            optGantryInd = zeros(1,updatedInfo.totalNumOfShapes);
            gantryAngles = [updatedInfo.beam(:).gantryAngle];
            
            sectorBorderGantryAngles = nan(1,numel(updatedInfo.beam));
            borderLeftLeafPoss = nan(dimZ,numel(updatedInfo.beam)+2);
            
            l = 1;
            m = 1;
            for k = 1:numel(updatedInfo.beam)
                if updatedInfo.beam(k).numOfShapes
                    vectorIx     = updatedInfo.beam(k).shape(1).vectorOffset + ([1:dimZ]-1);
                    leftLeafPoss(:,l) = apertureInfoVect(vectorIx);
                    rightLeafPoss(:,l) = apertureInfoVect(vectorIx+updatedInfo.totalNumOfLeafPairs);
                    optWeights(l) = apertureInfoVect(l);
                    optGantryAngles(l) = updatedInfo.beam(k).gantryAngle;
                    optGantryInd(l) = k;
                    if l <= updatedInfo.totalNumOfShapes-1
                        nextOptTime(l) = apertureInfoVect(updatedInfo.totalNumOfShapes+updatedInfo.totalNumOfLeafPairs*2+l);
                    end
                    if l~=1
                        ind = find(gantryAngles == optGantryAngles(l-1));
                        
                        updatedInfo.beam(ind).MU = optWeights(l-1)*updatedInfo.weightToMU;
                        updatedInfo.beam(ind).time = nextOptTime(l-1);
                        updatedInfo.beam(ind).gantryRot = (optGantryAngles(l)-optGantryAngles(l-1))/updatedInfo.beam(ind).time;
                        updatedInfo.beam(ind).MURate = updatedInfo.beam(ind).MU*updatedInfo.beam(ind).gantryRot/(gantryAngles(ind+1)-gantryAngles(ind));
                        
                        if l == numel(updatedInfo.beam)
                            %this is for the last optimized gantry angle.
                            %it has the same rotation speed as the last
                            %angle, and a slightly modified MU rate (scaled
                            %by the weight of the beam)
                            updatedInfo.beam(l).MU = optWeights(l)*updatedInfo.weightToMU;
                            updatedInfo.beam(l).gantryRot = updatedInfo.beam(ind).gantryRot;
                            updatedInfo.beam(l).MURate = updatedInfo.beam(ind).MURate*optWeights(l-1)/optWeights(l-2);
                            
                            %optWeights(l-1)*updatedInfo.weightToMU*updatedInfo.beam(ind).gantryRot/(gantryAngles(ind)-gantryAngles(ind-1));
                        end
                    end
                    
                    l = l+1;
                end
                
                if touchingFlag
                    %Only important when cleaning up instances of opposing
                    %leaves touching.
                    if ~isempty(updatedInfo.beam(k).leafDir)
                        %This gives starting angle of the current sector.
                        sectorBorderGantryAngles(m) = updatedInfo.beam(k).borderAngles(1);
                        
                        if updatedInfo.beam(k).leafDir == 1
                            %This means that the current arc sector is moving
                            %in the normal direction (L-R).
                            borderLeftLeafPoss(:,m) = updatedInfo.beam(k).lim_l;
                        elseif updatedInfo.beam(k).leafDir == -1
                            %This means that the current arc sector is moving
                            %in the reverse direction (R-L).
                            borderLeftLeafPoss(:,m) = updatedInfo.beam(k).lim_r;
                        end
                        m = m+1;
                        
                        %end of last sector
                        if updatedInfo.beam(k).borderAngles(2) == 360
                            %This gives ending angle of the current sector.
                            sectorBorderGantryAngles(m) = updatedInfo.beam(k).borderAngles(2); %starting angle of current sector
                            if updatedInfo.beam(k).leafDir == 1
                                %This means that the current arc sector is moving
                                %in the normal direction (L-R), so the next arc
                                %sector is moving opposite
                                borderLeftLeafPoss(:,m) = updatedInfo.beam(k).lim_r;
                            elseif updatedInfo.beam(k).leafDir == -1
                                %This means that the current arc sector is moving
                                %in the reverse direction (R-L), so the next
                                %arc sector is moving opposite
                                borderLeftLeafPoss(:,m) = updatedInfo.beam(k).lim_l;
                            end
                        end
                    end
                end
            end
            
            
            sectorBorderGantryAngles(isnan(sectorBorderGantryAngles)) = [];
            borderLeftLeafPoss(isnan(borderLeftLeafPoss)) = [];
            borderLeftLeafPoss = reshape(borderLeftLeafPoss,dimZ,[]);
            
            if touchingFlag
                %Any time leaf pairs are touching, they are set to
                %be in the middle of the field.  Instead, move them
                %so that they are still touching, but that they
                %follow the motion of the MLCs across the field.
                for row = 1:dimZ
                    
                    touchingInd = find(leftLeafPoss(row,:) == rightLeafPoss(row,:) & leftLeafPoss(row,:) == 0*leftLeafPoss(row,:));
                    
                    if numel(touchingInd) == size(leftLeafPoss,2)
                        %Leaves in this row are touching for all gantry angles/segments.
                        %Set leaf positions to centre of mass position, so that
                        %they follow the trajectory of the rest of the leaves.
                        %Since all leaves are sliding window, COM is also
                        %sliding window
                        for col = touchingInd
                            indTouching = find(leftLeafPoss(:,col) == rightLeafPoss(:,col));
                            notIndTouching = setdiff(1:dimZ,indTouching);
                            leftLeafPoss(row,col) = mean([mean(leftLeafPoss(notIndTouching,col),1),mean(rightLeafPoss(notIndTouching,col),1)]);
                            rightLeafPoss(row,col) = leftLeafPoss(row,col);
                        end
                    elseif ~isempty(touchingInd)
                        %Leaves are only touching for some gantry
                        %angles/segments.  Interpolate leaf positions between
                        %non-touching segments, to minimize leaf travel, taking
                        %care of any instances of leaf touching at border
                        %angles (end of arc sector)
                        
                        if ~exist('leftLeafPossAug','var')
                            %leftLeafPossAug = [reshape(mean([leftLeafPoss(:) rightLeafPoss(:)],2),size(leftLeafPoss)),borderLeftLeafPoss];
                            leftLeafPossAugTemp = reshape(mean([leftLeafPoss(:) rightLeafPoss(:)],2),size(leftLeafPoss));
                            
                            numRep = 0;
                            repInd = nan(size(optGantryAngles));
                            for j = 1:numel(optGantryAngles)
                                if any(optGantryAngles(j) == sectorBorderGantryAngles)
                                    %replace leaf positions with the ones at
                                    %the borders (eliminates repetitions)
                                    numRep = numRep+1;
                                    %these are the gantry angles that are
                                    %repeated
                                    repInd(numRep) = j;
                                    
                                    delInd = find(optGantryAngles(j) == sectorBorderGantryAngles);
                                    leftLeafPossAugTemp(:,j) = borderLeftLeafPoss(:,delInd);
                                    borderLeftLeafPoss(:,delInd) = [];
                                    sectorBorderGantryAngles(delInd) = [];
                                end
                            end
                            repInd(isnan(repInd)) = [];
                            leftLeafPossAug = [leftLeafPossAugTemp,borderLeftLeafPoss];
                            gantryAnglesAug = [optGantryAngles,sectorBorderGantryAngles];
                            
                            notTouchingInd = [setdiff(1:updatedInfo.totalNumOfShapes,touchingInd),repInd];
                            notTouchingInd = unique(notTouchingInd);
                            %make sure to include the repeated ones in the
                            %interpolation!
                            
                            notTouchingIndAug = [notTouchingInd,(1+numel(optGantryAngles)):(numel(optGantryAngles)+numel(sectorBorderGantryAngles))];
                            
                        end
                        
                        leftLeafPoss(row,touchingInd) = interp1(gantryAnglesAug(notTouchingIndAug),leftLeafPossAug(row,notTouchingIndAug),optGantryAngles(touchingInd));
                        rightLeafPoss(row,touchingInd) = leftLeafPoss(row,touchingInd);
                        
                    end
                end
            end
        end
        
        % loop over all shapes
        for j = 1:updatedInfo.beam(i).numOfShapes
            % update the shape weight
            updatedInfo.beam(i).shape(j).weight = apertureInfoVect(shapeInd);
            
            % get dimensions of 2d matrices that store shape/bixel information
            n = apertureInfo.beam(i).numOfActiveLeafPairs;
            
            
            if isfield(apertureInfo,'gantryRotCst')
                %Perform interpolation
                currGantryAngle = updatedInfo.beam(i).gantryAngle;
                leftLeafPos = (interp1(optGantryAngles',leftLeafPoss',currGantryAngle))';
                rightLeafPos = (interp1(optGantryAngles',rightLeafPoss',currGantryAngle))';
                
                %re-update vector in case anything changed from fixing the leaf
                %touching
                vectorIx = updatedInfo.beam(i).shape(j).vectorOffset + ([1:n]-1);
                apertureInfoVect(vectorIx) = leftLeafPos;
                apertureInfoVect(vectorIx+apertureInfo.totalNumOfLeafPairs) = rightLeafPos;
            else
                % extract left and right leaf positions from shape vector
                vectorIx     = updatedInfo.beam(i).shape(j).vectorOffset + ([1:n]-1);
                leftLeafPos  = apertureInfoVect(vectorIx);
                rightLeafPos = apertureInfoVect(vectorIx+apertureInfo.totalNumOfLeafPairs);
            end
            
            % update information in shape structure
            updatedInfo.beam(i).shape(j).leftLeafPos  = leftLeafPos;
            updatedInfo.beam(i).shape(j).rightLeafPos = rightLeafPos;
            
            % rounding for numerical stability
            leftLeafPos  = round2(leftLeafPos,10);
            rightLeafPos = round2(rightLeafPos,10);
            
            %
            xPosIndLeftLeaf  = round((leftLeafPos - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth + 1);
            xPosIndRightLeaf = round((rightLeafPos - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth + 1);
            
            %
            xPosIndLeftLeaf_lim  = floor((apertureInfo.beam(i).lim_l - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth+1);
            xPosIndRightLeaf_lim = ceil((apertureInfo.beam(i).lim_r - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth + 1);
            
            xPosIndLeftLeaf(xPosIndLeftLeaf <= xPosIndLeftLeaf_lim) = xPosIndLeftLeaf_lim(xPosIndLeftLeaf <= xPosIndLeftLeaf_lim)+1;
            xPosIndRightLeaf(xPosIndRightLeaf >= xPosIndRightLeaf_lim) = xPosIndRightLeaf_lim(xPosIndRightLeaf >= xPosIndRightLeaf_lim)-1;
            
            
            % check limits because of rounding off issues at maximum, i.e.,
            % enforce round(X.5) -> X
            % LeafPos can occasionally go slightly beyond lim_r, so changed
            % == check to >=
            xPosIndLeftLeaf(leftLeafPos >= apertureInfo.beam(i).lim_r) = ...
                .5 + (leftLeafPos(leftLeafPos >= apertureInfo.beam(i).lim_r) ...
                - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth;
            
            xPosIndRightLeaf(rightLeafPos >= apertureInfo.beam(i).lim_r) = ...
                .5 + (rightLeafPos(rightLeafPos >= apertureInfo.beam(i).lim_r) ...
                - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth;
            %{
            xPosIndLeftLeaf(leftLeafPos == apertureInfo.beam(i).lim_r) = ...
                .5 + (leftLeafPos(leftLeafPos == apertureInfo.beam(i).lim_r) ...
                - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth;
            xPosIndRightLeaf(rightLeafPos == apertureInfo.beam(i).lim_r) = ...
                .5 + (rightLeafPos(rightLeafPos == apertureInfo.beam(i).lim_r) ...
                - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth;
            %}
                
                
            % find the bixel index that the leaves currently touch
            bixelIndLeftLeaf  = apertureInfo.beam(i).bixelIndMap((xPosIndLeftLeaf-1)*n+[1:n]');
            bixelIndRightLeaf = apertureInfo.beam(i).bixelIndMap((xPosIndRightLeaf-1)*n+[1:n]');
            
            if any(isnan(bixelIndLeftLeaf)) || any(isnan(bixelIndRightLeaf))
                error('cannot map leaf position to bixel index');
            end
            
            % store information in index vector for gradient calculation
            indVect(offset+[1:n]) = bixelIndLeftLeaf;
            indVect(offset+[1:n]+apertureInfo.realTotalNumOfLeafPairs) = bixelIndRightLeaf;
            offset = offset+n;
            
            % calculate opening fraction for every bixel in shape to construct
            % bixel weight vector
            
            coveredByLeftLeaf  = bsxfun(@minus,leftLeafPos,edges_l)  / updatedInfo.bixelWidth;
            coveredByRightLeaf = bsxfun(@minus,edges_r,rightLeafPos) / updatedInfo.bixelWidth;
            
            tempMap = 1 - (coveredByLeftLeaf  + abs(coveredByLeftLeaf))  / 2 ...
                - (coveredByRightLeaf + abs(coveredByRightLeaf)) / 2;
            
            % find open bixels
            tempMapIx = tempMap > 0;
            
            currBixelIx = apertureInfo.beam(i).bixelIndMap(tempMapIx);
            w(currBixelIx) = w(currBixelIx) + tempMap(tempMapIx)*updatedInfo.beam(i).shape(j).weight;
            
            % save the tempMap (we need to apply a positivity operator !)
            updatedInfo.beam(i).shape(j).shapeMap = (tempMap  + abs(tempMap))  / 2;
            
            % increment shape index
            shapeInd = shapeInd +1;
        end
        
    else
        %This should only occur for VMAT subchildren angles, i.e., not
        %independently optimized
        %Interpolate this segment between adjacent optimized gantry angles.
        % Include in updatedInfo, but NOT the vector (since these are not
        % optimized by DAO).  Also update bixel weights to include these.
        if ~exist('leftLeafPoss','var')
            
            %Only collect this data once, to save time
            dimZ = updatedInfo.beam(1).numOfActiveLeafPairs;
            leftLeafPoss = nan(dimZ,updatedInfo.totalNumOfShapes); %Each non-interpolated beam should have 1 and only 1 shape
            rightLeafPoss = nan(dimZ,updatedInfo.totalNumOfShapes);
            optWeights = zeros(1,updatedInfo.totalNumOfShapes);
            nextOptTime = zeros(1,updatedInfo.totalNumOfShapes-1);
            optGantryAngles = zeros(1,updatedInfo.totalNumOfShapes);
            optGantryInd = zeros(1,updatedInfo.totalNumOfShapes);
            gantryAngles = [updatedInfo.beam(:).gantryAngle];
            
            sectorBorderGantryAngles = nan(1,numel(updatedInfo.beam));
            borderLeftLeafPoss = nan(dimZ,numel(updatedInfo.beam));
            
            l = 1;
            m = 1;
            for k = 1:numel(updatedInfo.beam)
                if updatedInfo.beam(k).numOfShapes
                    vectorIx     = updatedInfo.beam(k).shape(1).vectorOffset + ([1:dimZ]-1);
                    leftLeafPoss(:,l) = apertureInfoVect(vectorIx);
                    rightLeafPoss(:,l) = apertureInfoVect(vectorIx+updatedInfo.totalNumOfLeafPairs);
                    optWeights(l) = apertureInfoVect(l);
                    optGantryAngles(l) = updatedInfo.beam(k).gantryAngle;
                    optGantryInd(l) = k;
                    if l <= updatedInfo.totalNumOfShapes-1
                        nextOptTime(l) = apertureInfoVect(updatedInfo.totalNumOfShapes+updatedInfo.totalNumOfLeafPairs*2+l);
                    end
                    if l~=1
                        ind = find(gantryAngles == optGantryAngles(l-1));
                        if ind ~= numel(updatedInfo.beam)
                            updatedInfo.beam(ind).MU = optWeights(l-1)*updatedInfo.weightToMU;
                            updatedInfo.beam(ind).time = nextOptTime(l-1);
                            updatedInfo.beam(ind).gantryRot = (optGantryAngles(l)-optGantryAngles(l-1))/updatedInfo.beam(ind).time;
                            updatedInfo.beam(ind).MURate = updatedInfo.beam(ind).MU*updatedInfo.beam(ind).gantryRot/(gantryAngles(ind+1)-gantryAngles(ind));
                            lastInd = ind;
                        else
                            %this is for the last optimized gantry angle.
                            %it has the same rotation speed as the last
                            %angle, and a slightly modified MU rate (scaled
                            %by the weight of the beam)
                            updatedInfo.beam(ind).MU = optWeights(l-1)*updatedInfo.weightToMU;
                            updatedInfo.beam(ind).gantryRot = updatedInfo.beam(lastInd).gantryRot;
                            updatedInfo.beam(ind).MURate = updatedInfo.beam(ind).MURate*optWeights(l-1)/optWeights(l-2);
                            
                            %optWeights(l-1)*updatedInfo.weightToMU*updatedInfo.beam(ind).gantryRot/(gantryAngles(ind)-gantryAngles(ind-1));
                        end
                    end
                    
                    l = l+1;
                end
                
                if touchingFlag
                    %Only important when cleaning up instances of opposing
                    %leaves touching.
                    if ~isempty(updatedInfo.beam(k).leafDir)
                        %This gives starting angle of the current sector.
                        sectorBorderGantryAngles(m) = updatedInfo.beam(k).borderAngles(1);
                        if updatedInfo.beam(k).leafDir == 1
                            %This means that the current arc sector is moving
                            %in the normal direction (L-R).
                            borderLeftLeafPoss(:,m) = updatedInfo.beam(k).lim_l;
                        elseif updatedInfo.beam(k).leafDir == -1
                            %This means that the current arc sector is moving
                            %in the reverse direction (R-L).
                            borderLeftLeafPoss(:,m) = updatedInfo.beam(k).lim_r;
                        end
                        m = m+1;
                        
                        %end of last sector
                        if updatedInfo.beam(k).borderAngles(2) == 360
                            %This gives ending angle of the current sector.
                            sectorBorderGantryAngles(m) = updatedInfo.beam(k).borderAngles(2); %starting angle of current sector
                            if updatedInfo.beam(k).leafDir == 1
                                %This means that the current arc sector is moving
                                %in the normal direction (L-R), so the next arc
                                %sector is moving opposite
                                borderLeftLeafPoss(:,m) = updatedInfo.beam(k).lim_r;
                            elseif updatedInfo.beam(k).leafDir == -1
                                %This means that the current arc sector is moving
                                %in the reverse direction (R-L), so the next
                                %arc sector is moving opposite
                                borderLeftLeafPoss(:,m) = updatedInfo.beam(k).lim_l;
                            end
                        end
                    end
                end
            end
            
            
            sectorBorderGantryAngles(isnan(sectorBorderGantryAngles)) = [];
            borderLeftLeafPoss(isnan(borderLeftLeafPoss)) = [];
            borderLeftLeafPoss = reshape(borderLeftLeafPoss,dimZ,[]);
            
            if touchingFlag
                %Any time leaf pairs are touching, they are set to
                %be in the middle of the field.  Instead, move them
                %so that they are still touching, but that they
                %follow the motion of the MLCs across the field.
                for row = 1:dimZ
                    
                    touchingInd = find(leftLeafPoss(row,:) == rightLeafPoss(row,:) && leftLeafPoss(row,:) == 0*leftLeafPoss(row,:));
                    
                    if numel(touchingInd) == size(leftLeafPoss,2)
                        %Leaves in this row are touching for all gantry angles/segments.
                        %Set leaf positions to centre of mass position, so that
                        %they follow the trajectory of the rest of the leaves.
                        %Since all leaves are sliding window, COM is also
                        %sliding window
                        for col = touchingInd
                            indTouching = find(leftLeafPoss(:,col) == rightLeafPoss(:,col));
                            notIndTouching = setdiff(1:dimZ,indTouching);
                            leftLeafPoss(row,col) = mean([mean(leftLeafPoss(notIndTouching,col),1),mean(rightLeafPoss(notIndTouching,col),1)]);
                            rightLeafPoss(row,col) = leftLeafPoss(row,col);
                        end
                    elseif ~isempty(touchingInd)
                        %Leaves are only touching for some gantry
                        %angles/segments.  Interpolate leaf positions between
                        %non-touching segments, to minimize leaf travel, taking
                        %care of any instances of leaf touching at border
                        %angles (end of arc sector)
                        gantryAnglesAug = [optGantryAngles,sectorBorderGantryAngles];
                        
                        leftLeafPossAug = [reshape(mean([leftLeafPoss(:) rightLeafPoss(:)],2),size(leftLeafPoss)),borderLeftLeafPoss];
                        
                        notTouchingInd = setdiff(1:updatedInfo.totalNumOfShapes,touchingInd);
                        notTouchingIndAug = [notTouchingInd,(1+numel(optGantryAngles)):(numel(optGantryAngles)+numel(sectorBorderGantryAngles))];
                        
                        leftLeafPoss(row,touchingInd) = interp1(gantryAnglesAug(notTouchingIndAug),leftLeafPossAug(row,notTouchingIndAug),optGantryAngles(touchingInd));
                        rightLeafPoss(row,touchingInd) = leftLeafPoss(row,touchingInd);
                        
                    end
                end
            end
        end
        
        % get dimensions of 2d matrices that store shape/bixel information
        n = apertureInfo.beam(i).numOfActiveLeafPairs;
        
        %Perform interpolation
        currGantryAngle = updatedInfo.beam(i).gantryAngle;
        leftLeafPos = (interp1(optGantryAngles',leftLeafPoss',currGantryAngle))';
        rightLeafPos = (interp1(optGantryAngles',rightLeafPoss',currGantryAngle))';
        
        %assume doserate is piecewise linear over arc sector
        %assume gantry rotation speed is constant over arc sector
        %updatedInfo.beam(i).MURate = interp1([updatedInfo.beam(i).lastOptAngle updatedInfo.beam(i).nextOptAngle],[updatedInfo.beam(updatedInfo.beam(i).lastOptInd).MURate updatedInfo.beam(updatedInfo.beam(i).nextOptInd).MURate],gantryAngles(i));
        
        updatedInfo.beam(i).fracFromLast = (updatedInfo.beam(i).nextOptAngle-gantryAngles(i))/(updatedInfo.beam(i).nextOptAngle-updatedInfo.beam(i).lastOptAngle);
        updatedInfo.beam(i).MURate = updatedInfo.beam(i).fracFromLast*updatedInfo.beam(updatedInfo.beam(i).lastOptInd).MURate+(1-updatedInfo.beam(i).fracFromLast)*updatedInfo.beam(updatedInfo.beam(i).nextOptInd).MURate;
        if i ~= numel(updatedInfo.beam)
            weight = updatedInfo.beam(updatedInfo.beam(i).lastOptInd).MURate*(gantryAngles(i+1)-gantryAngles(i))/(updatedInfo.beam(updatedInfo.beam(i).lastOptInd).gantryRot*updatedInfo.weightToMU);
        else
            weight = updatedInfo.beam(updatedInfo.beam(i).lastOptInd).MURate*(gantryAngles(i)-gantryAngles(i-1))/(updatedInfo.beam(updatedInfo.beam(i).lastOptInd).gantryRot*updatedInfo.weightToMU);
        end
        
        % update information in shape structure
        updatedInfo.beam(i).shape(1).leftLeafPos  = leftLeafPos;
        updatedInfo.beam(i).shape(1).rightLeafPos = rightLeafPos;
        updatedInfo.beam(i).shape(1).weight = weight;
        updatedInfo.beam(i).shape(1).MU = weight*updatedInfo.weightToMU;
        
        %The following is taken from the non-VMAT case (j->1, since there is only 1
        %shape per beam in VMAT)
        % rounding for numerical stability
        leftLeafPos  = round2(leftLeafPos,10);
        rightLeafPos = round2(rightLeafPos,10);
        
        %
        xPosIndLeftLeaf  = round((leftLeafPos - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth + 1);
        xPosIndRightLeaf = round((rightLeafPos - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth + 1);
        
        % check limits because of rounding off issues at maximum, i.e.,
        % enforce round(X.5) -> X
        xPosIndLeftLeaf(leftLeafPos == apertureInfo.beam(i).lim_r) = ...
            .5 + (leftLeafPos(leftLeafPos == apertureInfo.beam(i).lim_r) ...
            - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth;
        xPosIndRightLeaf(rightLeafPos == apertureInfo.beam(i).lim_r) = ...
            .5 + (rightLeafPos(rightLeafPos == apertureInfo.beam(i).lim_r) ...
            - apertureInfo.beam(i).posOfCornerBixel(1))/apertureInfo.bixelWidth;
        
        % find the bixel index that the leaves currently touch
        bixelIndLeftLeaf  = apertureInfo.beam(i).bixelIndMap((xPosIndLeftLeaf-1)*dimZ+[1:dimZ]');
        bixelIndRightLeaf = apertureInfo.beam(i).bixelIndMap((xPosIndRightLeaf-1)*dimZ+[1:dimZ]');
        
        if any(isnan(bixelIndLeftLeaf)) || any(isnan(bixelIndRightLeaf))
            error('cannot map leaf position to bixel index');
        end
        
        % store information in index vector for gradient calculation
        indVect(offset+[1:n]) = bixelIndLeftLeaf;
        indVect(offset+[1:n]+apertureInfo.realTotalNumOfLeafPairs) = bixelIndRightLeaf;
        offset = offset+n;
        
        % calculate opening fraction for every bixel in shape to construct
        % bixel weight vector
        
        coveredByLeftLeaf  = bsxfun(@minus,leftLeafPos,edges_l)  / updatedInfo.bixelWidth;
        coveredByRightLeaf = bsxfun(@minus,edges_r,rightLeafPos) / updatedInfo.bixelWidth;
        
        tempMap = 1 - (coveredByLeftLeaf  + abs(coveredByLeftLeaf))  / 2 ...
            - (coveredByRightLeaf + abs(coveredByRightLeaf)) / 2;
        
        % find open bixels
        tempMapIx = tempMap > 0;
        
        currBixelIx = apertureInfo.beam(i).bixelIndMap(tempMapIx);
        w(currBixelIx) = w(currBixelIx) + tempMap(tempMapIx)*updatedInfo.beam(i).shape(1).weight;
        
        % save the tempMap (we need to apply a positivity operator !)
        updatedInfo.beam(i).shape(1).shapeMap = (tempMap  + abs(tempMap))  / 2;
        
    end
    
    
end

updatedInfo.bixelWeights = w;
updatedInfo.bixelIndices = indVect;
updatedInfo.apertureVector = apertureInfoVect;

end