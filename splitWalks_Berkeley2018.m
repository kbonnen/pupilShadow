
close all
clear all
restoredefaultpath


if ispc
    
    
    dataPath = 'E:\Dropbox\UTexas\OpticFlowProject';
    cd(dataPath);
    
elseif ismac
    
    cd /Users/matthis/Dropbox/UTexas/OpticFlowProject
    
    dataPath = '/Users/matthis/Dropbox/UTexas/OpticFlowProject';
    
    cd(dataPath);
end


%%Add the folders relevant to the experiment to the path
addpath(genpath(cd))
rmpath('Analyses_oldVSS2017era')
rmpath('old')
rmpath('Data')

%%Add the folders relevant to the experiment to the path
addpath(genpath(cd))
path = cd;

berkeley2018Data = true; opticFlowData = ~berkeley2018;

%% Load the session specific details

spotcheck = false;

numSubs = 3;
numConds = 2;

for sub = 1%:numSubs
    
    switch sub
        case 1
            sessionID = '2018-01-23_JSM';
        case 2
            sessionID = '2018-01-26_JAC';
        case 3
            sessionID = '2018-01-31_JAW';
    end
    
    for cond = 1:2
        
        switch cond
            case 1
                condID = 'Woodchips';
            case 2
                condID = 'Rocks';
        end
        
        clearvars -except cond condID dataPath numConds numSubs path sessionID sub spotcheck woodchips rocks subPath woodchipsVOR rocksVOR
        
        subPath = strcat(dataPath,filesep,'Data',filesep, sessionID);
        addpath(genpath(subPath))
        shadowDataPath = strcat(dataPath,filesep,'Data',filesep, sessionID,filesep,condID,filesep,'Shadow',filesep);
        pupilDataPath = strcat(dataPath,filesep,'Data',filesep,sessionID,filesep,condID,filesep,'Pupil',filesep);
        
        
        splitWalks_date = datetime;
        
        cd(subPath)
        cd('OutputFiles')
        
        disp(strcat({'loading '},strcat(pwd,filesep,condID,'.mat')));
        
        load(strcat(pwd,filesep,condID,'.mat'));
        %%
        
        saveOutData = true;
        debug = true;
        
        %%
        
        
        %%
        %%% clip out data relevant to each walk, zeroing and rotating as necessary
        
        clear allWalks
        walks = sesh.walks;
        comXYZ = squeeze(shadow_fr_mar_dim(:,1,:));
        
        walks = [vorFrames([1 end]);walks]; %add VorFrames to beginning of 'Walks' variable, in order to build VOR Calibration struct
        for ww = 1:length(walks)
            
            
            ww
            
            thisWalk = [];
            
            %% load various bits of data into struct
            
            thisWalk.avg_fps = round(mean(diff(syncedUnixTime).^-1));
            thisWalk.shadowMarkerNames = shadowMarkerNames;
            thisWalk.calibDist = calibDist;
            thisWalk.legLength = sesh.legLength;
            thisWalk.rVorCalibErr = rVorCalibErr;
            thisWalk.lVorCalibErr = lVorCalibErr;
            
            thisWalk.splitWalks_date = datetime;
            thisWalk.processData_date = processData_date ;
            
            thisWalk.sessionID = sessionID;
            thisWalk.subID = subID;
            thisWalk.condID = condID;
            
            %% comXYZ
            thisWalk.comXYZ = comXYZ(walks(ww,1): walks(ww,2),:);
            
            zCom = thisWalk.comXYZ(1, :); %this is the original comXYZ start point, used to zero other data.
            
            thisWalk.comXYZ(:, 1) = thisWalk.comXYZ(:, 1) - zCom(1); %zero X data
            thisWalk.comXYZ(:, 3) = thisWalk.comXYZ(:, 3) - zCom(3); %zero Z data
            
            %these won't change for the other data downstream
            if ww == 1
                pt0 = calibPoint([1 3]); %for the VOR frames, use the Calib point to define the "end point"
                pt1 = pt0; %don't rotate VOR data
                thisWalk.isThisVORCalibrationData = true;
            elseif ww>1
                pt0 = thisWalk.comXYZ(end, [1 3]); %original endpoint
                pt1 = [1000 0]; %positive-X vector 
                thisWalk.isThisVORCalibrationData = false;
            end
            
            origin = thisWalk.comXYZ(1, [1 3]); %startpoint
            
            
            %the data to be rotated
            X = thisWalk.comXYZ(:,1); %original X
            Z = thisWalk.comXYZ(:,3); %original Z (Y)
            
            disp('rotating COM')
            [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
            
            if spotcheck; dbstack; keyboard; end
            thisWalk.comXYZ = [x_r' thisWalk.comXYZ(:,2) z_r'];
            
            %% ground fixations (R)
            thisWalk.rGazeGroundIntersection = rGazeGroundIntersection(walks(ww,1): walks(ww,2),:);
            
            thisWalk.rGazeGroundIntersection(:, 1) = thisWalk.rGazeGroundIntersection(:, 1) - zCom(1); %zero X data
            thisWalk.rGazeGroundIntersection(:, 3) = thisWalk.rGazeGroundIntersection(:, 3) - zCom(3); %zero Z data
            
            X = thisWalk.rGazeGroundIntersection(:,1); %original X
            Z = thisWalk.rGazeGroundIntersection(:,3); %original Z (Y)
            
            disp('rotating rGazeGroundIntersection')
            
            [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
            
            if spotcheck; dbstack; keyboard; end
            
            thisWalk.rGazeGroundIntersection = [x_r' thisWalk.rGazeGroundIntersection(:,2) z_r'];
            
            %% ground fixations (L)
            thisWalk.lGazeGroundIntersection = lGazeGroundIntersection(walks(ww,1): walks(ww,2),:);
            
            thisWalk.lGazeGroundIntersection(:, 1) = thisWalk.lGazeGroundIntersection(:, 1) - zCom(1); %zero X data
            thisWalk.lGazeGroundIntersection(:, 3) = thisWalk.lGazeGroundIntersection(:, 3) - zCom(3); %zero Z data
            
            X = thisWalk.lGazeGroundIntersection(:,1); %original X
            Z = thisWalk.lGazeGroundIntersection(:,3); %original Z (Y)
            
            disp('rotating lGazeGroundIntersection')
            
            [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
            
            if spotcheck; dbstack; keyboard; end
            
            thisWalk.lGazeGroundIntersection = [x_r' thisWalk.lGazeGroundIntersection(:,2) z_r'];
            
            %% rEyeballCenterXYZ
            thisWalk.rEyeballCenterXYZ = rEyeballCenterXYZ(walks(ww,1): walks(ww,2),:);
            
            thisWalk.rEyeballCenterXYZ(:, 1) = thisWalk.rEyeballCenterXYZ(:, 1) - zCom(1); %zero X data
            thisWalk.rEyeballCenterXYZ(:, 3) = thisWalk.rEyeballCenterXYZ(:, 3) - zCom(3); %zero Z data
            
            X = thisWalk.rEyeballCenterXYZ(:,1); %original X
            Z = thisWalk.rEyeballCenterXYZ(:,3); %original Z (Y)
            
            disp('rotating rEyeballCenterXYZ')
            
            [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
            
            if spotcheck; dbstack; keyboard; end
            
            
            thisWalk.rEyeballCenterXYZ = [x_r' thisWalk.rEyeballCenterXYZ(:,2) z_r'];
            
            %% lEyeballCenterXYZ
            thisWalk.lEyeballCenterXYZ = lEyeballCenterXYZ(walks(ww,1): walks(ww,2),:);
            
            thisWalk.lEyeballCenterXYZ(:, 1) = thisWalk.lEyeballCenterXYZ(:, 1) - zCom(1); %zero X data
            thisWalk.lEyeballCenterXYZ(:, 3) = thisWalk.lEyeballCenterXYZ(:, 3) - zCom(3); %zero Z data
            
            X = thisWalk.lEyeballCenterXYZ(:,1); %original X
            Z = thisWalk.lEyeballCenterXYZ(:,3); %original Z (Y)
            
            disp('rotating lEyeballCenterXYZ')
            
            [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
            
            if spotcheck; dbstack; keyboard; end
            
            
            thisWalk.lEyeballCenterXYZ = [x_r' thisWalk.lEyeballCenterXYZ(:,2) z_r'];
            
            
            
            %% shadow data
            thisWalk.shadow_fr_mar_dim = shadow_fr_mar_dim(walks(ww,1): walks(ww,2),:,:);
            
            s = thisWalk.shadow_fr_mar_dim;
            
            disp('rotating Marker Data')
            for mm = 1:length(s(1,:,1))
                thisM = squeeze(s(:,mm,:));
                
                thisM(:, 1) = thisM(:, 1) - zCom(1); %zero X data
                thisM(:, 3) = thisM(:, 3) - zCom(3); %zero X data
                
                X = thisM(:,1); %original X
                Z = thisM(:,3); %original Z (Y)
                
                
                [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
                hold on
                s(:,mm,:) = [x_r' thisM(:,2) z_r'];
            end
            
            if spotcheck; dbstack; keyboard; end; hold off
            
            thisWalk.shadow_fr_mar_dim = s;
            
            %% rGazeXYZ
            thisWalk.rGazeXYZ= rGazeXYZ(walks(ww,1): walks(ww,2),:);
            
            thisWalk.rGazeXYZ(:, 1) = thisWalk.rGazeXYZ(:, 1) - zCom(1); %zero X data
            thisWalk.rGazeXYZ(:, 3) = thisWalk.rGazeXYZ(:, 3) - zCom(3); %zero Z data
            
            X = thisWalk.rGazeXYZ(:,1); %original X
            Z = thisWalk.rGazeXYZ(:,3); %original Z (Y)
            
            
            
            disp('rotating rGazeXYZ')
            [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
            
            if spotcheck; dbstack; keyboard; end
            
            thisWalk.rGazeXYZ = [x_r' thisWalk.rGazeXYZ(:,2) z_r'];
            
            
            %% lGazeXYZ
            thisWalk.lGazeXYZ= lGazeXYZ(walks(ww,1): walks(ww,2),:);
            
            thisWalk.lGazeXYZ(:, 1) = thisWalk.lGazeXYZ(:, 1) - zCom(1); %zero X data
            thisWalk.lGazeXYZ(:, 3) = thisWalk.lGazeXYZ(:, 3) - zCom(3); %zero Z data
            
            X = thisWalk.lGazeXYZ(:,1); %original X
            Z = thisWalk.lGazeXYZ(:,3); %original Z (Y)
            
            disp('rotating lGazeXYZ')
            [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
            
            if spotcheck; dbstack; keyboard; end
            
            thisWalk.lGazeXYZ = [x_r' thisWalk.lGazeXYZ(:,2) z_r'];
            
            %% headVecX_fr_xyz
            thisWalk.headVecX_fr_xyz= headVecX_fr_xyz(walks(ww,1): walks(ww,2),:);
            
            X = thisWalk.headVecX_fr_xyz(:,1); %original X
            Z = thisWalk.headVecX_fr_xyz(:,3); %original Z (Y)
            
            disp('rotating headVecX_fr_xyz')
            [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
            
            if spotcheck; dbstack; keyboard; end
            
            thisWalk.headVecX_fr_xyz = [x_r' thisWalk.headVecX_fr_xyz(:,2) z_r'];
            
            %% headVecY_fr_xyz
            thisWalk.headVecY_fr_xyz= headVecY_fr_xyz(walks(ww,1): walks(ww,2),:);
            
            X = thisWalk.headVecY_fr_xyz(:,1); %original X
            Z = thisWalk.headVecY_fr_xyz(:,3); %original Z (Y)
            
            disp('rotating headVecY_fr_xyz')
            [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
            
            if spotcheck; dbstack; keyboard; end
            
            thisWalk.headVecY_fr_xyz = [x_r' thisWalk.headVecY_fr_xyz(:,2) z_r'];
            
            %% headVecZ_fr_xyz
            thisWalk.headVecZ_fr_xyz= headVecZ_fr_xyz(walks(ww,1): walks(ww,2),:);
            
            X = thisWalk.headVecZ_fr_xyz(:,1); %original X
            Z = thisWalk.headVecZ_fr_xyz(:,3); %original Z (Y)
            
            disp('rotating headVecZ_fr_xyz')
            [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
            
            if spotcheck; dbstack; keyboard; end
            
            thisWalk.headVecZ_fr_xyz = [x_r' thisWalk.headVecZ_fr_xyz(:,2) z_r'];
            %% step data
            if ww > 1
                theseStepIDs = steps_HS_TO_StanceLeg_XYZ(:,1)>=walks(ww,1) & steps_HS_TO_StanceLeg_XYZ(:,1)<=walks(ww,2);
                
                thisWalk.steps_HS_TO_StanceLeg_XYZ = steps_HS_TO_StanceLeg_XYZ(theseStepIDs,:);
                
                
                thisWalk.steps_HS_TO_StanceLeg_XYZ(:, 4) = thisWalk.steps_HS_TO_StanceLeg_XYZ(:, 4) - zCom(1); %zero X data
                thisWalk.steps_HS_TO_StanceLeg_XYZ(:, 6) = thisWalk.steps_HS_TO_StanceLeg_XYZ(:, 6) - zCom(3); %zero Z data
                
                X = thisWalk.steps_HS_TO_StanceLeg_XYZ(:,4); %original X
                Z = thisWalk.steps_HS_TO_StanceLeg_XYZ(:,6); %original Z (Y)
                
                disp('rotating Steps')
                [x_r, z_r] = rotateFromV0toV1(X, Z, pt0, pt1, origin, debug );
                
                if spotcheck; dbstack; keyboard; end
                
                thisWalk.steps_HS_TO_StanceLeg_XYZ(:,[4:6]) = [x_r' thisWalk.steps_HS_TO_StanceLeg_XYZ(:,5) z_r'];
                
                thisWalk.steps_HS_TO_StanceLeg_XYZ(:,1) = thisWalk.steps_HS_TO_StanceLeg_XYZ(:,1) - walks(ww,1);
                thisWalk.steps_HS_TO_StanceLeg_XYZ(:,2) = thisWalk.steps_HS_TO_StanceLeg_XYZ(:,2) - walks(ww,1);
                
            end
            %% add unrotated data
            
            
            thisWalk.rEye_norm_pos_x = rEye.norm_pos_x(walks(ww,1): walks(ww,2),:);
            thisWalk.rEye_norm_pos_y = rEye.norm_pos_y(walks(ww,1): walks(ww,2),:);
            
            thisWalk.lEye_norm_pos_x = lEye.norm_pos_x(walks(ww,1): walks(ww,2),:);
            thisWalk.lEye_norm_pos_y = lEye.norm_pos_y(walks(ww,1): walks(ww,2),:);
            
            thisWalk.world_norm_pos_x = gaze.norm_pos_x(walks(ww,1): walks(ww,2),:);
            thisWalk.world_norm_pos_y = gaze.norm_pos_y(walks(ww,1): walks(ww,2),:);
            
            
            thisWalk.rEye_pupRadius = rEye_pupRadius(walks(ww,1): walks(ww,2),:);
            thisWalk.lEye_pupRadius = lEye_pupRadius(walks(ww,1): walks(ww,2),:);
            
            
            thisWalk.frames = walks(ww,1): walks(ww,2);
            thisWalk.syncedUnixTime = syncedUnixTime(walks(ww,1): walks(ww,2));
            
            if opticFlowData
            thisWalk.FOExy_rrf = FOExy_rrf(walks(ww,1): walks(ww,2),:);
            thisWalk.FOExy_crf = FOExy_crf(walks(ww,1): walks(ww,2),:);
            
            thisWalk.flowMeanVy_rrf = flowMeanVy_rrf(walks(ww,1): walks(ww,2),:);
            thisWalk.flowMeanVy_crf = flowMeanVy_crf(walks(ww,1): walks(ww,2),:);
            thisWalk.flowMeanVx_rrf = flowMeanVx_rrf(walks(ww,1): walks(ww,2),:);
            thisWalk.flowMeanVx_crf = flowMeanVx_crf(walks(ww,1): walks(ww,2),:);
            thisWalk.flowMeanOr_rrf = flowMeanOr_rrf(walks(ww,1): walks(ww,2),:);
            thisWalk.flowMeanOr_crf = flowMeanOr_crf(walks(ww,1): walks(ww,2),:);
            thisWalk.flowMagStd_rrf = flowMagStd_rrf(walks(ww,1): walks(ww,2),:);
            thisWalk.flowMagStd_crf = flowMagStd_crf(walks(ww,1): walks(ww,2),:);
            thisWalk.flowMagMean_rrf = flowMagMean_rrf(walks(ww,1): walks(ww,2),:);
            thisWalk.flowMagMean_crf = flowMagMean_crf(walks(ww,1): walks(ww,2),:);
            thisWalk.flowMagMax_rrf = flowMagMax_rrf(walks(ww,1): walks(ww,2),:);
            thisWalk.flowMagMax_crf = flowMagMax_crf(walks(ww,1): walks(ww,2),:);
            
            thisWalk.porX = porX(walks(ww,1): walks(ww,2),:);
            thisWalk.porYvel = porYvel(walks(ww,1): walks(ww,2),:);
            thisWalk.porY = porY(walks(ww,1): walks(ww,2),:);
            thisWalk.porXvel = porXvel(walks(ww,1): walks(ww,2),:);
            
            end
            
            thisWalk.headAccXYZ = headAccXYZ(walks(ww,1): walks(ww,2),:);
            thisWalk.chestAccXYZ = chestAccXYZ(walks(ww,1): walks(ww,2),:);
            thisWalk.hipsAccXYZ = hipsAccXYZ(walks(ww,1): walks(ww,2),:);
            
            thisWalk.worldFrameIndex = rEye.index(walks(ww,1): walks(ww,2));
            
            
            %% correct for alignment error
            
            if ww > 1
                disp('calcking alignment error')
                
                
                
                thisWalk.walks = walks;
                
                thisWalk_orig = thisWalk;
                [thisWalk] = correctAlignmentError_opt(thisWalk_orig);
                
                figure(1100*sub+cond)
                plot(ww, thisWalk.rCorrAlignTheta, 'rp','MarkerFaceColor','r')
                hold on
                plot(ww, thisWalk.lCorrAlignTheta, 'bp','MarkerFaceColor','b')
                title('Alignment Correction Theta (red = right eye - should be similar to blue star)')
                ylim([-pi pi])
                
            end
            
            
            
            %% load a buncha individual marker datums into the struct
            
            rHeelID = find(strcmp('RightHeel', shadowMarkerNames));
            thisWalk.rHeelXYZ = squeeze(s(:,rHeelID,:)); % pull out rHeelID marker
            
            rToeID = find(strcmp('RightToe', shadowMarkerNames));
            thisWalk.rToeXYZ = squeeze(s(:,rToeID,:)); % pull out rHeelID marker
            
            rFootID = find(strcmp('RightFoot', shadowMarkerNames));
            thisWalk.rFootXYZ = squeeze(s(:,rFootID,:)); % pull out RightFoot marker
            
            
            lHeelID = find(strcmp('LeftHeel', shadowMarkerNames));
            thisWalk.lHeelXYZ = squeeze(s(:,lHeelID,:)); % pull out rHeelID marker
            
            lToeID = find(strcmp('LeftToe', shadowMarkerNames));
            thisWalk.lToeXYZ = squeeze(s(:,lToeID,:)); % pull out rHeelID marker000
            
            lFootID = find(strcmp('LeftFoot', shadowMarkerNames));
            thisWalk.lFootXYZ = squeeze(s(:,lFootID,:)); % pull out LeftFoot marker
            
            
            hTopID = find(strcmp('HeadTop', shadowMarkerNames));
            thisWalk.hTopXYZ= squeeze(s(:,hTopID,:)); % pull out LeftFoot marker
            
            hC1ID = find(strcmp('HeadTop', shadowMarkerNames));
            thisWalk.hC1XYZ= squeeze(s(:,hC1ID,:)); % pull out LeftFoot marker
            
            thisWalk.hCenXYZ = (thisWalk.hTopXYZ + thisWalk.hC1XYZ)/2;
            
            
            

            %%
            
            if ww == 1 %save VOR struct separately from AllWalks Struct
                switch cond
                    case 1
                        woodchipsVOR = thisWalk;
                    case 2
                        rocksVOR = thisWalk;
                end
                
            elseif ww > 1 %Don't do this part for the VOR Frames iteration
                allWalks{ww-1} = thisWalk;
            end
            
            figure(1000*sub+cond)
            
            %     if mod(ii,2); %% plot even/odd walks on differnet subplots (because even plots are rotated 180 from odd ones)
            %         subplot(311);
            %     else
            %         subplot(312)
            %     end
            subplot(round(length(walks)/2),2,ww)
            
            plot(thisWalk.comXYZ(:,1), thisWalk.comXYZ(:,3))
            
            hold on
            plot(thisWalk.rGazeGroundIntersection(:,1), thisWalk.rGazeGroundIntersection(:,3),'r.')
            plot(thisWalk.lGazeGroundIntersection(:,1), thisWalk.lGazeGroundIntersection(:,3),'b.')
            
            plot(thisWalk.comXYZ(1,1), thisWalk.comXYZ(1,3),'gp')
            plot(thisWalk.comXYZ(end,1), thisWalk.comXYZ(end,3),'rp')
            
            if ww > 1            
            plot(thisWalk.steps_HS_TO_StanceLeg_XYZ(1,4), thisWalk.steps_HS_TO_StanceLeg_XYZ(1,6),'go')
            plot(thisWalk.steps_HS_TO_StanceLeg_XYZ(end,4), thisWalk.steps_HS_TO_StanceLeg_XYZ(end,6),'ro')
            end
            axis equal
            
            
            if ww == 1
                title(strcat(condID,{' VOR Calibration '}))
            else
                title(strcat(condID,{' walk# '},num2str(ww)))
            end
            
            %     subplot(313)
            %     plot(comXYZ)
            %     hold on
            %     plot(walks(ii,1):walks(ii,2), comXYZ(walks(ii,1):walks(ii,2),3),'o')
            %     drawnow
            %     beep
            
            %%
        end
        
        
        %%
        switch cond
            case 1
                woodchips = allWalks;
            case 2
                rocks = allWalks;
        end
        
    end
    
    if saveOutData
        cd(subPath)
        cd 'OutputFiles'
        save('allWalks.mat','woodchips','rocks','woodchipsVOR','rocksVOR')
    end
    rmpath(subPath)
end

