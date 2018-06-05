tic

close all
clear all
restoredefaultpath

if ispc
    dataPath = 'E:\Dropbox\UTexas\OpticFlowProject';
    %     dataPath = 'E:/Dropbox/UTexas/KateBerkeley2018';
    cd(dataPath);
elseif ismac
    dataPath = '/Users/matthis/Dropbox/UTexas/OpticFlowProject';
    cd(dataPath);
end

%%Add the folders relevant to the experiment to the path 
addpath(genpath(cd))

%%remove folders that might cause problems (duplicate function names, etc)
rmpath('Analyses_oldVSS2017era')
rmath('old')
%also remove 'Data' folder so you don't wind up accidentally adding the wrong "take0001.csv" or something
rmpath('Data')


berkeley2018Data = true; opticFlowData = ~berkeley2018;

monocular = false;

for subNum = 1%:3
    
    
    %% Load the session specific details
    
    spotcheck = false;
    
    switch subNum
        
        case 1
            subID = 'JSM';
            sessionID = '2018-01-23_JSM';
            
        case 2
            subID = 'JAC';
            sessionID = '2018-01-26_JAC';
            
        case 3
            subID = 'JAW';
            sessionID = '2018-01-31_JAW';
    end
    
    for condNum = 1:2
        
        switch condNum
            case 1
                condID = 'Woodchips';
            case 2
                condID = 'Rocks';
        end
        
        
        clearvars -except condID condNum dataPath sessionID spotCheck subNum subID
        
        [ sesh ] = loadSessionInfo( sessionID, condID);
        shadowTakeName = sesh.shadowTakeName;
        walks = sesh.walks;
        vorFrames = sesh.vorFrames;
        calibFrame = vorFrames(1);
        
        legLength = sesh.legLength;
        bodyMass = sesh.bodyMass;
        resHeight = sesh.height;
        
        subPath = strcat(dataPath,filesep,'Data',filesep, sessionID);
%         addpath(genpath(subPath))
        
        shadowDataPath = strcat(dataPath,filesep,'Data',filesep, sessionID,filesep,condID,filesep,'Shadow',filesep);
        pupilDataPath = strcat(dataPath,filesep,'Data',filesep,sessionID,filesep,condID,filesep,'Pupil',filesep);
        
        
        processData_date = datetime;
        

        %%
        %% get Pupil Start Time Date & World time stamps
        %%%load starttime (hopefully will someday be updated to floating point precision
        cd(pupilDataPath)
        worldTimestamps = readNPY('world_timestamps.npy');

        delimiter = ',';
        formatSpec = '%q%q%[^\n\r]';
        fileID = fopen('info.csv','r');
        dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter,  'ReturnOnError', false);
        fclose(fileID);
        key = dataArray{:, 1};
        value = dataArray{:, 2};
        start_yr_month_day = strsplit(value{2},'_');
        start_hr_min_sec = strsplit(value{4},':');
        
        res = str2double(strsplit(value{strcmp(key, 'World Camera Resolution' )},'x'));
        
        resWidth = res(1);
        resHeight = res(2);
        
        
        pupilUnixStartTime = str2double(value{strcmp(key, 'Start Time (System)')});
        
        
        %%
        %%Load (previously processed) eye data - basically just a Mat file of all
        %%the data from the Positive Science output - The most important variables
        %%are porX, porY and porQTtimedhmstvts(timestamps)
        
        
        
        
        
        %% resample pupil data to enforce constant framerate
        
        % if exist([pwd filesep strcat('pupil_split_resampled.mat')], 'file') == 0 %if the resampled data isn't saved in a .mat file, build it from the .csv
        disp('resampling "pupil.mat", this could take a second...')
        
        
        cd(pupilDataPath)
        cd 'exports'
        d = dir;
        cd(d(end).name)

        prefRate = 120;
        

        
        pupilExportPath = pwd;
        
        [ rEye, lEye, gaze ] = fixPupilSamplingRate( pupilExportPath, prefRate, pupilUnixStartTime );
        
        save('pupil_split_resampled.mat','rEye','lEye');
        
        pupUnixTime = rEye.unixTimestamp;
                
        worldUnixTimestamp = (worldTimestamps-worldTimestamps(1)) + pupilUnixStartTime;

        %% %%%find frame of world video that most closely matches each rEye, lEye, and gaze dataframe
        assert(length(rEye.unixTimestamp) == length(lEye.unixTimestamp));
        assert(length(rEye.unixTimestamp) == length(gaze.unixTimestamp));
        
        rEye.index = nan(size(rEye.unixTimestamp));
        lEye.index = nan(size(lEye.unixTimestamp));
        gaze.index = nan(size(gaze.unixTimestamp));
        
        disp('Finding World Frame Indices')
        for ii = 1:length(rEye.norm_pos_x)
            [yy, rEye.index(ii)] = min(abs(rEye.unixTimestamp(ii) - worldUnixTimestamp));
            [yy, lEye.index(ii)] = min(abs(lEye.unixTimestamp(ii) - worldUnixTimestamp));
            [yy, gaze.index(ii)] = min(abs(gaze.unixTimestamp(ii) - worldUnixTimestamp));
        end
        %% Load Shadow Data
        disp('Doing spooky shadow data stuff')
        
        cd(shadowDataPath)
        
        streamFilename = strcat(shadowTakeName, '_stream.csv');
        headerline = 1;
        delimiter = ',';
        [streamData] = importdata(streamFilename,delimiter, headerline);
        
        
        
        
        % %% load shadow Markers
        % fid = strcat(takeName,'.c3d');
        %
        % [ c3dDataStruct  ] = loadC3dBtk( fid );
        %
        % shadowMarkerNamesC3d = c3dDataStruct.markerNames;
        % shadowFramerate = c3dDataStruct.framerate;
        %
        % shadowDataRaw.markerData = c3dDataStruct.c3dData_fr_mar_dim;
        %% build shadow skel variable from csv data (to avoid having to deal with c3d's, which are strangly proprietary...)
        
        colHead = streamData.colheaders';
        
        colSplit = cell(size(colHead));
        for cc = 1:length(colHead)
            thisColSplit = strsplit(colHead{cc},'.');
            
            colSplit{cc} = thisColSplit{1};
        end
        
        shadowMarkerNames = unique(colSplit,'stable');
        
        streamShadow_fr_mar_dim = nan(length(streamData.data(:,1)), length(shadowMarkerNames), 3);
        
        for mm = 1:length(shadowMarkerNames)
            %for each dimension (XYZ) - pull out linear translation data, and then multiply by 10 to convert cm's to mm's
            streamShadow_fr_mar_dim(:,mm,1) = streamData.data(:, strcmp(streamData.colheaders, strcat(shadowMarkerNames(mm),'.ltx')))*10;
            streamShadow_fr_mar_dim(:,mm,2) = streamData.data(:, strcmp(streamData.colheaders, strcat(shadowMarkerNames(mm),'.lty')))*10;
            streamShadow_fr_mar_dim(:,mm,3) = streamData.data(:, strcmp(streamData.colheaders, strcat(shadowMarkerNames(mm),'.ltz')))*10;
            
        end
        
        %% for infor about column heading names - https://www.motionshadow.com/download/media/configurable.xml
        
        shadowDataRaw.HeadGqw = streamData.data(:, strcmp(streamData.colheaders, 'Head.Gqw'));
        shadowDataRaw.HeadGqx = streamData.data(:, strcmp(streamData.colheaders, 'Head.Gqx'));
        shadowDataRaw.HeadGqy = streamData.data(:, strcmp(streamData.colheaders, 'Head.Gqy'));
        shadowDataRaw.HeadGqz  = streamData.data(:, strcmp(streamData.colheaders, 'Head.Gqz'));

        shadowDataRaw.HeadAccX  = streamData.data(:, strcmp(streamData.colheaders, 'Head.ax'));
        shadowDataRaw.HeadAccY  = streamData.data(:, strcmp(streamData.colheaders, 'Head.ay'));
        shadowDataRaw.HeadAccZ  = streamData.data(:, strcmp(streamData.colheaders, 'Head.az'));

        shadowDataRaw.ChestAccX  = streamData.data(:, strcmp(streamData.colheaders, 'Chest.ax'));
        shadowDataRaw.ChestAccY  = streamData.data(:, strcmp(streamData.colheaders, 'Chest.ay'));
        shadowDataRaw.ChestAccZ  = streamData.data(:, strcmp(streamData.colheaders, 'Chest.az'));
        
        shadowDataRaw.HipsAccX  = streamData.data(:, strcmp(streamData.colheaders, 'Hips.ax'));
        shadowDataRaw.HipsAccY  = streamData.data(:, strcmp(streamData.colheaders, 'Hips.ay'));
        shadowDataRaw.HipsAccZ  = streamData.data(:, strcmp(streamData.colheaders, 'Hips.az'));

        shadowDataRaw.og_time  = streamData.data(:, strcmp(streamData.colheaders, 'Head.time'));
        shadowDataRaw.markerData = streamShadow_fr_mar_dim;
        
        [shadowDataResamp] =  fixShadowSamplingRate( shadowDataRaw, prefRate );
        
        
        shadowTimeFromZero = shadowDataResamp.timestamp;
        
        %% adjust ShadowTime
        takeStruct = xml2struct('take.mTake'); % turns out '.mTake' files are just secret XML's!! :O
        shadowStartDateTime = takeStruct.take.start;
        t = strsplit(shadowStartDateTime.Text,{'-','T',':','Z'});
        shadowStartDateTime = datetime(str2num(t{1}),...
            str2num(t{2}),...
            str2num(t{3}),...
            str2num(t{4}),...
            str2num(t{5}),...
            str2num(t{6}));
        
        timezone = -6*60*60;
        shadowUnixStartTime = posixtime(shadowStartDateTime);%+timezone;
        
        
        shadowUnixTime = shadowTimeFromZero + shadowUnixStartTime;
        
        %% now that eye and shadow variables theoretically have the same framerate and temporal reference frame (UNIX epoch), trim them to be the same length/duration
        disp('trimming up timestamps')
        
        firstFrameTime = max([pupUnixTime(1) shadowUnixTime(1)]);
        lastFrameTime = min([pupUnixTime(end) shadowUnixTime(end)]);
        
        if lastFrameTime - firstFrameTime < 0
            warning('Something went wrong with the timestamps...')
            keyboard
        end
        
        
        trimFirstPupFrames = pupUnixTime<firstFrameTime;
        trimFirstShadowFrames = shadowUnixTime<firstFrameTime;
        trimFirstPupFrames = pupUnixTime<firstFrameTime;
        
        
        trimEndPupFrames = pupUnixTime>lastFrameTime;
        trimEndShadowFrames = shadowUnixTime>lastFrameTime;
        
        pupVarNames = fieldnames(rEye);
        shadowVarNames = fieldnames(shadowDataResamp);
        gazeVarNames = fieldnames(gaze);
        
        numPupilFrames = sum(~(trimFirstPupFrames|trimEndPupFrames));
        numShadowFrames = sum(~(trimFirstShadowFrames|trimEndShadowFrames));
        
        for pp = 1:length(pupVarNames) %% trim pupil data
            thisRvar = rEye.(pupVarNames{pp});
            thisLvar = lEye.(pupVarNames{pp});
            
            if size(thisRvar) == size(pupUnixTime)
                thisRvar(trimFirstPupFrames|trimEndPupFrames) = [];
                thisLvar(trimFirstPupFrames|trimEndPupFrames) = [];
                
                if size(thisRvar) ~= size(thisLvar)
                    dbstack
                    error('Problem in your pupil trimming code, yo.')
                else
                    rEye.(pupVarNames{pp}) =   thisRvar;
                    lEye.(pupVarNames{pp}) =   thisLvar;
                end
            end
        end
        
        
        
        for gg = 1:length(gazeVarNames) %% trim gaze data
            thisGvar = gaze.(gazeVarNames{gg});
            
            if size(thisGvar) == size(pupUnixTime)
                thisGvar(trimFirstPupFrames|trimEndPupFrames) = [];
                
                gaze.(gazeVarNames{gg}) =   thisGvar;
            end
        end
        
        
        
        %%% trim up yer shadow data
        skipThese = {'timestamp','markerData'}; %trim all the non marker data first
        for ss = 1:length(shadowVarNames)
            thisShadowVar = shadowDataResamp.(shadowVarNames{ss});
            
            if isempty(strmatch(shadowVarNames{ss}, skipThese))
                thisShadowVar(trimFirstShadowFrames|trimEndShadowFrames) = [];
                
                %%if this append or delete a frame from the end to make the shadow
                %%and pupil frames the same length. This trimming method sometimes
                %%makes them off by one.
                if numPupilFrames > length(thisShadowVar)
                    thisShadowVar(end+1) = nan;
                elseif numPupilFrames < length(thisShadowVar)
                    thisShadowVar(end) = [];
                end
                
                shadowDataTrimmed.(shadowVarNames{ss}) = thisShadowVar;
            end
        end
        
        
        c3d_fr_mar_dimRaw = shadowDataResamp.markerData;
        c3d_fr_mar_dimTrimmed = [];
        
        for mm = 1:length(squeeze(c3d_fr_mar_dimRaw(1,:,1))) % resample the marker data now
            
            thisMar_xyz = squeeze(c3d_fr_mar_dimRaw(:,mm,:));
            
            thisMar_xyz(trimFirstShadowFrames|trimEndShadowFrames,:) = [];
            
            if numPupilFrames > length(thisMar_xyz)
                thisMar_xyz(end+1,:) = nan;
            elseif numPupilFrames < length(thisMar_xyz)
                thisMar_xyz(end,:) = [];
            end
            
            
            c3d_fr_mar_dimTrimmed(:,mm,:) = thisMar_xyz;
        end
        
        shadowDataTrimmed.markerData = c3d_fr_mar_dimTrimmed;
        clear c3d_fr_mar_dimRaw c3d_fr_mar_dimTrimmed
        
        rt = pupUnixTime;
        rt(trimFirstPupFrames|trimEndPupFrames) = [];
        
        st = shadowUnixTime;
        st(trimFirstShadowFrames|trimEndShadowFrames) = [];
        

        shadowRAW_fr_mar_dim = shadowDataTrimmed.markerData;
        
        if length(shadowRAW_fr_mar_dim) ~= length(thisRvar)
            disp('problem with your time sync')
            keyboard
        end
        
        %% make variable of unix timestamps of synched data
        if length(st) > length(rt)
            syncedUnixTime = mean([st(1:length(rt)) rt]')';
        elseif length(rt) > length(st)
            syncedUnixTime = mean([rt(1:length(st)) st]')';
        elseif length(rt) == length(st)
            syncedUnixTime = mean([st rt]')';
        end        
        
        %% sync world timestamps & optic flow data
        
        if opticFlowData
            cd(pupilDataPath)
            cd(subPath)
            cd 'OutputFiles'
            of_matFile = matfile(strcat(sessionID,'_',condID,'_opticFlowStats.mat'));
            of_varlist = who(of_matFile);
            %%%Redistribute optic flow data into vector same length as pupil
            %%%and shadow data, but don't interpolate 'empty' frames, because
            %%%optic flow changes on a fast enough time scale that you dont
            %%%wanna do that
            
            
            
            
            for vv = 1:length(of_varlist)
                vv
                thisOFvarName =  of_varlist{vv};
                thisVarOrig = of_matFile.(thisOFvarName);
                
                if strcmp(thisOFvarName(1:3),'FOE')
                    thisVarRedist = nan(length(syncedUnixTime),2);
                else
                    thisVarRedist = nan(length(syncedUnixTime),1);
                end
                
                if abs(length(worldUnixTimestamp) -  length(thisVarOrig)+1) > length(worldUnixTimestamp)*.01
                    warning('Problem with the Optic Flow Data sync bit - Your variable is somewhat different from the # of world frames')
                    %             keyboard
                end
                
                %for each frame of the original data, find the frame in the
                %synched data that most closely matches the timestamp
                for ff = 1:length(thisVarOrig)
                    
                    thisOFframeTimestamp = worldUnixTimestamp(ff);
                    
                    if thisOFframeTimestamp < syncedUnixTime(1)
                        continue
                    else
                        [yy, ind] = min(abs(syncedUnixTime - thisOFframeTimestamp));%find nearest timestamp
                        
                        if strcmp(thisOFvarName(1:3),'FOE')
                            thisVarRedist(ind,:) = thisVarOrig(ff,:);
                        else
                            thisVarRedist(ind) = thisVarOrig(ff);
                        end
                    end
                    
                end
                
                %make variable to pour the new data into
                
                if strcmp(thisOFvarName , 'FOExy_crf');       FOExy_crf = thisVarRedist; end
                if strcmp(thisOFvarName , 'FOExy_rrf');       FOExy_rrf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMagMax_crf');  flowMagMax_crf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMagMax_rrf');  flowMagMax_rrf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMagMean_crf'); flowMagMean_crf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMagMean_rrf'); flowMagMean_rrf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMagStd_crf');  flowMagStd_crf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMagStd_rrf');  flowMagStd_rrf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMeanOr_crf');  flowMeanOr_crf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMeanOr_rrf');  flowMeanOr_rrf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMeanVx_crf');  flowMeanVx_crf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMeanVx_rrf');  flowMeanVx_rrf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMeanVy_crf');  flowMeanVy_crf = thisVarRedist; end
                if strcmp(thisOFvarName , 'flowMeanVy_rrf');  flowMeanVy_rrf = thisVarRedist; end
                if strcmp(thisOFvarName , 'porX');            porX = thisVarRedist; end
                if strcmp(thisOFvarName , 'porY');            porY = thisVarRedist; end
                if strcmp(thisOFvarName , 'porXvel');         porXvel = thisVarRedist; end
                if strcmp(thisOFvarName , 'porYvel');         porYvel = thisVarRedist; end
                
                
            end
        end
        
        
        
        %% Find Steps
        disp('Finding steps')
        wRaw.shadow_fr_mar_dim = shadowRAW_fr_mar_dim;
        wRaw.shadowMarkerNames = shadowMarkerNames;
        wRaw.avg_fps = mean(diff(syncedUnixTime).^-1);
        wRaw.walks = sesh.walks;
        
        [allSteps_HS_TO_StanceLeg] = ZeniStepFinder(wRaw);
        
        
        %% Try to fix 'skateboarding' problem by pinning the feet to the ground during each step
        disp('Fixing Skateboards')
        [shadow_fr_mar_dim] = fixSkateboarding_kb(wRaw, allSteps_HS_TO_StanceLeg);
        
        %% build step_TO_HS_ft_XYZ variable (in the most obfuscated way humanly possible)
        
        rHeelXYZ = squeeze(shadow_fr_mar_dim(:,strcmp('RightHeel', shadowMarkerNames),:)); % pull out lHeel marker
        lHeelXYZ = squeeze(shadow_fr_mar_dim(:,strcmp('LeftHeel', shadowMarkerNames),:)); % pull out lHeel marker
        
        
        steps_HS_TO_StanceLeg_XYZ = nan(length(allSteps_HS_TO_StanceLeg), 6);
        
        for i = 1:length(allSteps_HS_TO_StanceLeg)
            if allSteps_HS_TO_StanceLeg(i,3) == 1 %Right foot is on the ground
                steps_HS_TO_StanceLeg_XYZ(i,:) = [allSteps_HS_TO_StanceLeg(i,1) allSteps_HS_TO_StanceLeg(i,2) allSteps_HS_TO_StanceLeg(i,3) rHeelXYZ(allSteps_HS_TO_StanceLeg(i,1),1)  rHeelXYZ(allSteps_HS_TO_StanceLeg(i,1),2)  rHeelXYZ(allSteps_HS_TO_StanceLeg(i,1),3) ];
                
            elseif allSteps_HS_TO_StanceLeg(i,3) == 2 %Left foot is on the round
                steps_HS_TO_StanceLeg_XYZ(i,:) = [allSteps_HS_TO_StanceLeg(i,1) allSteps_HS_TO_StanceLeg(i,2) allSteps_HS_TO_StanceLeg(i,3)  lHeelXYZ(allSteps_HS_TO_StanceLeg(i,1),1) lHeelXYZ(allSteps_HS_TO_StanceLeg(i,1),2) lHeelXYZ(allSteps_HS_TO_StanceLeg(i,1),3) ];
            end
            
            
        end
        
        if true %%debug plot of sorts
            figure(6484)
            if steps_HS_TO_StanceLeg_XYZ(i,3) == 1 %Right foot is on the ground
                plot(steps_HS_TO_StanceLeg_XYZ(i,4), steps_HS_TO_StanceLeg_XYZ(i,6), 'ro','MarkerFaceColor','r')
                hold on
            elseif steps_HS_TO_StanceLeg_XYZ(i,3) == 2 %left foot is on the ground
                plot(steps_HS_TO_StanceLeg_XYZ(i,4), steps_HS_TO_StanceLeg_XYZ(i,6), 'bo','MarkerFaceColor','b')
            end
            
        end
        axis equal
        hold off
        
        
        
        
        %% maybe later :(
        % %% Swap Y and Z dimensions in Shadow Data so that Z points up, because Z should point up, dammit!
        
        % for mm = 1:length(shadow_fr_mar_dim(1,:,1))
        %
        %     thisMar =  squeeze(shadow_fr_mar_dim(:,mm,:));
        %     shadow_fr_mar_dim(:,mm,2) = -thisMar(:,3); %replace current Y(vertical) data with Z(leftward) data (Y = -Z, because rotation, I guess)
        %     shadow_fr_mar_dim(:,mm,3) = thisMar(:,2); %replace current Z(leftward) data with Y(verical) data
        %     clear thisMar %and let us never speak of this again...
        % end
        
        %% pull out head/chest/hips acceleration
        headAccXYZ(:,1) = shadowDataTrimmed.HeadAccX;
        headAccXYZ(:,2) = shadowDataTrimmed.HeadAccY;
        headAccXYZ(:,3) = shadowDataTrimmed.HeadAccZ;
        
        chestAccXYZ(:,1) = shadowDataTrimmed.ChestAccX;
        chestAccXYZ(:,2) = shadowDataTrimmed.ChestAccY;
        chestAccXYZ(:,3) = shadowDataTrimmed.ChestAccZ;
        
        hipsAccXYZ(:,1) = shadowDataTrimmed.HipsAccX;
        hipsAccXYZ(:,2) = shadowDataTrimmed.HipsAccY;
        hipsAccXYZ(:,3) = shadowDataTrimmed.HipsAccZ;
        
        %% Make Head rotation matrices
        HeadGqw = shadowDataTrimmed.HeadGqw;
        HeadGqx = shadowDataTrimmed.HeadGqx;
        HeadGqy = shadowDataTrimmed.HeadGqy;
        HeadGqz = shadowDataTrimmed.HeadGqz;
        
        
        headGlobalQuat_wxyz = normalize(quaternion(HeadGqw, HeadGqx, HeadGqy, HeadGqz));% + quaternion(sqrt(.5), sqrt(.5), 0, 0)); %rotate by 90 degs about X axis to make Z point up
        
        headRotMat_row_col_fr = headGlobalQuat_wxyz.RotationMatrix;
        
        %frames where EITHER toe or heel marker was carrying weight
        % shadowAnalogs = shadowData.analogs;
        % shadowAngles = shadowData.angles;
        % lftWeight = shadowAnalogs.LeftFoot_weight;
        % rtWeight = shadowAnalogs.RightFoot_weight;
        
        
        %% pull out all your eyeball variables
        %%% center of the eyeball sphere (subtract this from everything else so all relevant rays originate from [0 0 0])
        rEye_sphCenCam_x = rEye.sphere_center_x;
        lEye_sphCenCam_x = lEye.sphere_center_x;
        
        rEye_sphCenCam_y = rEye.sphere_center_y;
        lEye_sphCenCam_y = lEye.sphere_center_y;
        
        rEye_sphCenCam_z = rEye.sphere_center_z;
        lEye_sphCenCam_z = lEye.sphere_center_z;
        
        
        %%% center of the pupil
        rEye_pupCircCen_x = rEye.circle_3d_center_x;
        lEye_pupCircCen_x = lEye.circle_3d_center_x;
        
        rEye_pupCircCen_y = rEye.circle_3d_center_y;
        lEye_pupCircCen_y = lEye.circle_3d_center_y;
        
        rEye_pupCircCen_z = rEye.circle_3d_center_z;
        lEye_pupCircCen_z = lEye.circle_3d_center_z;
        
        %%% normal of pupil (used to plot the pupil patch correctly. TBH, I don't really understand how this variable works. Or what units it is in. Or much of anything, really...
        %%% update: probably mm's, probably originating from pupCircCenter
        rEye_norm_x = rEye.circle_3d_normal_x;
        lEye_norm_x = lEye.circle_3d_normal_x;
        
        rEye_norm_y = rEye.circle_3d_normal_y;
        lEye_norm_y = lEye.circle_3d_normal_y;
        
        rEye_norm_z = rEye.circle_3d_normal_z;
        lEye_norm_z = lEye.circle_3d_normal_z;
        
        %%%pupil radius (or diameter? the txt document is unclear on this point,
        %%%despite the unambiguious variable name. lucky I don't care about this
        %%%variable! Pupilometry is overated)
        rEye_pupRadius = rEye.circle_3d_radius;
        lEye_pupRadius = lEye.circle_3d_radius;
        
        %%%confidence
        rEye_confidence = rEye.confidence;
        lEye_confidence = lEye.confidence;
        
        %%% remove 0's, though nan's can screw other things up down the line
        rEye_pupCircCen_x(rEye_pupCircCen_x==0) = nan;
        rEye_pupCircCen_y(rEye_pupCircCen_y==0) = nan;
        rEye_pupCircCen_z(rEye_pupCircCen_z==0) = nan;
        
        lEye_pupCircCen_x(lEye_pupCircCen_x==0) = nan;
        lEye_pupCircCen_y(lEye_pupCircCen_y==0) = nan;
        lEye_pupCircCen_z(lEye_pupCircCen_z==0) = nan;
        
        rEye_norm_x(rEye_norm_x == 0) = nan;
        rEye_norm_y(rEye_norm_y == 0) = nan;
        rEye_norm_z(rEye_norm_z == 0) = nan;
        
        lEye_norm_x(lEye_norm_x == 0) = nan;
        lEye_norm_y(lEye_norm_y == 0) = nan;
        lEye_norm_z(lEye_norm_z == 0) = nan;
        
        rEye_pupRadius(rEye_pupRadius==0) = nan;
        lEye_pupRadius(lEye_pupRadius==0) = nan;
        
        %% calcu head orientation vector (mostly for debugging, tbh)
        
        headVecX_fr_xyz = nan(length(headRotMat_row_col_fr),3);
        headVecY_fr_xyz = nan(length(headRotMat_row_col_fr),3);
        headVecZ_fr_xyz = nan(length(headRotMat_row_col_fr),3);
        
        for mm = 1:length(headRotMat_row_col_fr)
            %         if mod(mm,1000) == 0 ; disp(strcat({'Rotating Head Unit vectors: '},num2str(mm),{' of '}, num2str(length(headRotMat_row_col_fr)))); end
            headVecX_fr_xyz(mm,:) =  headRotMat_row_col_fr(:,:,mm)* [1; 0; 0]; %rotate a unit vector to point in the same direction as the head (or something like that)
            headVecY_fr_xyz(mm,:) =  headRotMat_row_col_fr(:,:,mm)* [0; 1; 0];
            headVecZ_fr_xyz(mm,:) =  headRotMat_row_col_fr(:,:,mm)* [0; 0; 1];
        end
        
        
        
        
        
        
        plotHead = false;
        sphRes = 30;
        r = 50;
        [th, phi] = meshgrid(linspace(0, 2*pi, sphRes), linspace(-pi, pi, sphRes));
        [x1,y1,z1] = sph2cart(th, phi, r);
        if plotHead
            for mm = 1:length(headRotMat_row_col_fr)
                mm
                
                if mm>5000 && mod(mm,10) ==0
                    figure(393)
                    cla
                    mesh(x1,y1,z1,'EdgeColor',[.8 .8 .8],'FaceColor','none');
                    hold on
                    plot3([0 1], [0 0], [0 0], '-rp') %x-vector, aka magnetic north
                    plot3([0 0], [0 1], [0 0], '-gp') %y-vector, aka West
                    plot3([0 0], [0 0], [0 1], '-bp') %z-vector, aka vertical
                    
                    %plot head orientation
                    plot3([0 headVec_fr_xyz(mm,1)],[0 headVec_fr_xyz(mm,2)],[0 headVec_fr_xyz(mm,3)],'-mo','LineWidth',2)
                    plot3([headVec_fr_xyz(mm-100:mm,1)],[headVec_fr_xyz(mm-100:mm,2)],[headVec_fr_xyz(mm-100:mm,3)],'-mo','LineWidth',2)
                    
                    xlim([-1 1])
                    ylim([-1 1])
                    zlim([-1 1])
                    daspect([1 1 1])
                    drawnow
                end
            end
        end
        
        
        %% Rotate shadow skel, maybe?
        
        % [ shadow_fr_mar_dim ] = rotateShadowSkel( shadow_fr_mar_dim, shadowMarkerNames, headVec_fr_xyz, calibFrame );
        
        
        %% % %% time sync, maybe
        % headXnormed = (headVec_fr_xyz(:,1)./max(headVec_fr_xyz(:,1)));% - mean(headVec_fr_xyz(:,1)./max(headVec_fr_xyz(:,1)));
        % headYnormed = (headVec_fr_xyz(:,2)./max(headVec_fr_xyz(:,2)));% - mean(headVec_fr_xyz(:,2)./max(headVec_fr_xyz(:,2)));
        % headZnormed = (headVec_fr_xyz(:,3)./max(headVec_fr_xyz(:,3)));% - mean(headVec_fr_xyz(:,3)./max(headVec_fr_xyz(:,3)));
        %
        % rEyeXnormed = (rEye_norm_x) - nanmean(rEye_norm_x);
        % rEyeYnormed = (rEye_norm_y) - nanmean(rEye_norm_y);
        % rEyeZnormed = (rEye_norm_z) - nanmean(rEye_norm_z);
        %
        % figure(39484);clf
        % plot(headXnormed+9,'r-');hold on
        % plot(headYnormed+6,'g-');
        % plot(headZnormed+3,'b-');
        %
        % plot(rEye.norm_pos_x,'r.-');hold on
        % plot(rEye.norm_pos_y./max(rEye.norm_pos_y)+7,'g.-');
        %
        
        
        %% find eye positions in Shadow reference frame
        
        [ rEyeballCenterXYZ, lEyeballCenterXYZ,worldCamCenterXYZ ] = findEyePositions(headGlobalQuat_wxyz, shadow_fr_mar_dim, shadowMarkerNames,  calibFrame);
        for iii = 1:200
            disp('Your eyeball finder is bad and you should feel bad')
        end
        disp('Maybe its not *THAT* bad...? ')
        
        %% calc calib mat points
        [ calibPoint ] = calcCalibPoint( shadow_fr_mar_dim, shadowMarkerNames, calibFrame);
        
        
        %% align yr wiggly bits
        %%% Find a temporal offset to align shadow and pupil streams using the
        %%% 'head nod' part of the calibration
        
        % [rEyeOffset, lEyeOffset] = calcTemporalOffset(headVecX_fr_xyz, rEye, lEye, sesh.wiggleFrames);
        
        
        %% calibrate yr eyeballs (and yr WorldCamGaze guy)!
        %% %%% VOR FRAME METHOD - find camera alignment (i.e. the rotations needed for to make gaze vector align with calibration points during vorFrames)
        
        %right eye first
        vData.dataType                =       1; %1 = right eye, 2 = left eye, 3 = world cam
        vData.calibPoint            = calibPoint;
        vData.eyeballCenterXYZ      = rEyeballCenterXYZ(vorFrames,:);
        
        vData.confidence            = rEye_confidence(vorFrames);
        vData.eye_pupCircCen_x      = rEye_pupCircCen_x(vorFrames,:);
        vData.eye_pupCircCen_y      = rEye_pupCircCen_y(vorFrames,:);
        vData.eye_pupCircCen_z      = rEye_pupCircCen_z(vorFrames,:);
        
        vData.eye_sphCenCam_x     = rEye_sphCenCam_x(vorFrames,:);
        vData.eye_sphCenCam_y     = rEye_sphCenCam_y(vorFrames,:);
        vData.eye_sphCenCam_z     = rEye_sphCenCam_z(vorFrames,:);
        
        vData.headRotMat_row_col_fr        = headRotMat_row_col_fr(:,:,vorFrames);
        vData.shadow_fr_mar_dim     = squeeze(shadow_fr_mar_dim(vorFrames,:,:));
        vData.rHeelXYZ              = rHeelXYZ(vorFrames,:);
        vData.lHeelXYZ              = lHeelXYZ(vorFrames,:);
        vData.shadowMarkerNames     = shadowMarkerNames;
        vData.plotDebug             = true;
        
        vorAlignLossFun = @(camAlignEulerGuess) vorPupilAlignErrFun_eyeCam(vData, camAlignEulerGuess);
        
        initialCamEulerGuess = [0 0 0]; %starting guess for camAlignRotMat
        
        
        opts = optimset('Display', 'iter', 'MaxFunEvals',5000, 'PlotFcns',{@optimplotx, @optimplotfval,@optimplotfirstorderopt});
        
        [camAlignEuler, rVorCalibErr] = fminunc(vorAlignLossFun, initialCamEulerGuess, opts);
        
        
        camAlignQuat= quaternion.eulerangles('123',camAlignEuler(1),camAlignEuler(2),camAlignEuler(3));
        rEyeAlignRotMat = camAlignQuat.RotationMatrix;
        
        
        
        
        % now for the left eye
        clear vData
        vData.dataType                =       2; %1 = right eye, 2 = left eye, 3 = world camvData.headRotMat_row_col_fr        = headRotMat_row_col_fr(:,:,vorFrames);
        vData.calibPoint            = calibPoint;
        vData.eyeballCenterXYZ      = lEyeballCenterXYZ(vorFrames,:);
        
        vData.confidence            = lEye_confidence(vorFrames);
        vData.eye_pupCircCen_x      = lEye_pupCircCen_x(vorFrames,:);
        vData.eye_pupCircCen_y      = lEye_pupCircCen_y(vorFrames,:);
        vData.eye_pupCircCen_z      = lEye_pupCircCen_z(vorFrames,:);
        
        vData.eye_sphCenCam_x     = lEye_sphCenCam_x(vorFrames,:);
        vData.eye_sphCenCam_y     = lEye_sphCenCam_y(vorFrames,:);
        vData.eye_sphCenCam_z     = lEye_sphCenCam_z(vorFrames,:);
        
        vData.headRotMat_row_col_fr        = headRotMat_row_col_fr(:,:,vorFrames);
        vData.shadow_fr_mar_dim     = squeeze(shadow_fr_mar_dim(vorFrames,:,:));
        vData.rHeelXYZ              = rHeelXYZ(vorFrames,:);
        vData.lHeelXYZ              = lHeelXYZ(vorFrames,:);
        vData.shadowMarkerNames     = shadowMarkerNames;
        vData.plotDebug             = true;
        
        vorAlignLossFun = @(camAlignEulerGuess) vorPupilAlignErrFun_eyeCam(vData, camAlignEulerGuess);
        
        initialCamEulerGuess = [0 0 0]; %starting guess for camAlignRotMat
        
        
        opts = optimset('Display', 'iter', 'MaxFunEvals',5000, 'PlotFcns',{@optimplotx, @optimplotfval,@optimplotfirstorderopt});
        
        [camAlignEuler, lVorCalibErr] = fminunc(vorAlignLossFun, initialCamEulerGuess, opts);
        
        
        camAlignQuat= quaternion.eulerangles('123',camAlignEuler(1),camAlignEuler(2),camAlignEuler(3));
        lEyeAlignRotMat = camAlignQuat.RotationMatrix;
        
        
        
        
        
        
        %%
        % And once more for the worldCameraGaze (i.e. the crosshairs on the wrold
        % cam screen, this part is similar to what I did in Matthis, Yates, Hayhoe
        % 2018)
        %
        
        %%% First,fix up the POR data from the World Camera frame to prep it for 3D calibration
        
        %%% calc px2mmScale (from 'fixPupilVid.m) - 2018-04-19
        % % % % JSM Woodchips
        % tapePxX = [849,1063;835,1060;843,1064;855,1067;856,1068;857,1071;862,1073;844,1059;849,1063;566,798;552,782;821,1040;831,1046]
        % tapePxY = [815,820;1011,1012;937,941;729.000000000000,735.000000000000;734.000000000000,736;558.000000000000,562.000000000000;555.000000000000,560.000000000000;779,781;768.000000000000,770;793,781;792,779;774,773;766.000000000000,767.000000000000]
        
        % % % JSM Rocks
        % tapePxX =[885,1094;874,1084;878,1088;879,1087;882,1092;881,1091;882,1093;884,1092;881,1091;880,1091;882,1093;882,1094;880,1096;876,1096;875,1098];
        % tapePxY =[819,803;814,800;813,799;812,797;808,792;810,795;811,797;811,796;808,795;811,799;823,808;881,868;933,919;984,970;1053,1037];
        %
        %         %[x,y] pixel coordinates of either end of .5m tape at ~vorFrames(1)
        %         calibTape1 = [tapePxX(:,1) tapePxY(:,1)];
        %         calibTape2 = [tapePxX(:,2) tapePxY(:,2)];
        %         scaleDist = sqrt( (calibTape1(:,1)-calibTape2(:,1)).^2 + (calibTape1(:,2)-calibTape2(:,2)).^2); %euclidean distance between pt1 & pt2 (size of 0.5m tape in pixel units)
        %
        %         scaleSize = 500;
        %         px2mmScale = scaleSize/mean(scaleDist);
        
        if ~(resWidth == 1920 && resHeight == 1080)
            disp('Be Aware - The px2mmScale value here assumes 1920x1080 resolution, and this video is some other resolution.')
            keyboard
        end
        
        px2mmScale =2.3232;
       
        
        %rotate by 90
        %x_rot = x*cox(theta) - y*sin(theta); y_rot = x*sin(theta) + y*cons(theta)
        
        % porX = -porYo;
        % porY = porXo;
        
        porXzs = (porX )*px2mmScale;
        porYzs = (porY )*px2mmScale;
        
        calibDist = mean(sqrt( (worldCamCenterXYZ(calibFrame,1) - calibPoint(1)).^2 + ...
            (worldCamCenterXYZ(calibFrame,2) - calibPoint(2)).^2+...
            (worldCamCenterXYZ(calibFrame,3) - calibPoint(3)).^2));
        
        porXa = 2*atand((porXzs*.5)/calibDist);
        porYa = 2*atand((porYzs*.5)/calibDist);
        
        [worldCamGazeAz, worldCamGazeEl, worldCamGazeR] = cart2sph(porXzs, -porYzs, ones(length(porXzs), 1)*calibDist);
        
        [wGazeXYZ(:,1),wGazeXYZ(:,2),wGazeXYZ(:,3)] = sph2cart(worldCamGazeAz, worldCamGazeEl, ones(length(porX), 1)*calibDist);
        
        patchXo = [-resWidth -resWidth resWidth resWidth -resWidth ] *px2mmScale;
        patchYo = [-resHeight resHeight resHeight -resHeight -resHeight]*px2mmScale;
        patchZo = [calibDist calibDist calibDist calibDist calibDist];
        patchXYZ = [patchXo; patchYo; patchZo]; %each COLUMN is one of the 5 XYZ vectors needed to define the corners of a square patch centered on [0,0,-calibDist]
        
        clear vData
        
        
        
        vData.dataType                =       3; %1 = right eye, 2 = left eye, 3 = world camvData.headRotMat_row_col_fr        = headRotMat_row_col_fr(:,:,vorFrames);
        vData.calibPoint            = calibPoint;
        
        vData.worldCamCenterXYZ      = worldCamCenterXYZ(vorFrames,:);
        
        vData.confidence            = gaze.confidence(vorFrames);
        
        vData.gazeXYZ = wGazeXYZ(vorFrames,:);
        
        vData.headRotMat_row_col_fr        = headRotMat_row_col_fr(:,:,vorFrames);
        vData.shadow_fr_mar_dim     = squeeze(shadow_fr_mar_dim(vorFrames,:,:));
        vData.rHeelXYZ              = rHeelXYZ(vorFrames,:);
        vData.lHeelXYZ              = lHeelXYZ(vorFrames,:);
        vData.shadowMarkerNames     = shadowMarkerNames;
        vData.patchXYZ               = patchXYZ;
        vData.plotDebug             = true;
        
        vorAlignLossFun = @(camAlignEulerGuess) vorPupilAlignErrFun_worldCam(vData, camAlignEulerGuess);
        
        initialCamEulerGuess = [0 0 0]; %starting guess for camAlignRotMat
        
        
        opts = optimset('Display', 'iter', 'MaxFunEvals',5000, 'PlotFcns',{@optimplotx, @optimplotfval,@optimplotfirstorderopt});
        
        [camAlignEuler, wVorCalibErr] = fminunc(vorAlignLossFun, initialCamEulerGuess, opts);
        
        
        camAlignQuat= quaternion.eulerangles('123',camAlignEuler(1),camAlignEuler(2),camAlignEuler(3));
        wEyeAlignRotMat = camAlignQuat.RotationMatrix;
        
        %% Calc gaze vectors
        
        %Right Eye First!
        
        rGazeXYZ = [rEye_pupCircCen_x rEye_pupCircCen_y rEye_pupCircCen_z] ...  Take your "PupilCircleCenter" (in 3D Eye camera coordinate system, units are mm)
            -[rEye_sphCenCam_x  rEye_sphCenCam_y  rEye_sphCenCam_z];        %Subtract EyeSphereCenter (in eye camera coordiates) >> Origin is now at the center of the EyeSphere in camera coords
        
        %normalize its length
        for ll = 1:length(rGazeXYZ)
            rGazeXYZ(ll,:) = rGazeXYZ(ll,:)/norm(rGazeXYZ(ll,:));
        end
        %multiply it by your desired length ;)
        calibDist = pdist([rEyeballCenterXYZ(calibFrame,:); calibPoint]); %myboy pythag
        rGazeXYZ = rGazeXYZ*calibDist*10;
        
        
        %%%%
        %%%%%%% This part's important - Rotate gaze vector by the camera alignment matrix from the "vorAlignLossFun' (aka rEyeAlignRotMat) & head orientation (in that order), prior to resituating  the origin on on the eyeball
        %%%%
        
        for rr = 1:length(rGazeXYZ)
            
            thisET_frame_unrot = rEyeAlignRotMat * [rGazeXYZ(rr,1); rGazeXYZ(rr,2); rGazeXYZ(rr,3)];
            thisETframe = headRotMat_row_col_fr(:,:,rr) * thisET_frame_unrot;
            
            
            rGazeXYZ(rr,:) = thisETframe;
            
        end
        
        % add the eyeball center (in shadow/world coordiates) to translate origin of gaze vector onto the shadow eyeball
        rGazeXYZ(:,1) = rGazeXYZ(:,1)+ rEyeballCenterXYZ(:,1);
        rGazeXYZ(:,2) = rGazeXYZ(:,2)+ rEyeballCenterXYZ(:,2);
        rGazeXYZ(:,3) = rGazeXYZ(:,3)+ rEyeballCenterXYZ(:,3);
        
        
        
        
        
        %Once more for the eye that's Left
        
        lGazeXYZ = [lEye_pupCircCen_x lEye_pupCircCen_y lEye_pupCircCen_z] ...  Take your "PupilCircleCenter" (in 3D Eye camera coordinate system, units are mm)
            -[lEye_sphCenCam_x  lEye_sphCenCam_y  lEye_sphCenCam_z];        %Subtract EyeSphereCenter (in eye camera coordiates) >> Origin is now at the center of the EyeSphere in camera coords
        
        %normalize its length
        for ll = 1:length(lGazeXYZ)
            lGazeXYZ(ll,:) = lGazeXYZ(ll,:)/norm(lGazeXYZ(ll,:));
        end
        
        %multiply it by your desired length ;)
        calibDist = pdist([lEyeballCenterXYZ(calibFrame,:); calibPoint]); %myboy pythag
        lGazeXYZ = lGazeXYZ*calibDist*10;
        
        
        %%%%
        %%%%%%% This part's important - Rotate gaze vector by the camera alignment matrix from the "vorAlignLossFun' (aka lEyeAlignRotMat) & head orientation (in that order), prior to resituating  the origin on on the eyeball
        %%%%
        
        for rr = 1:length(lGazeXYZ)
            
            thisET_frame_unrot = lEyeAlignRotMat * [lGazeXYZ(rr,1); lGazeXYZ(rr,2); lGazeXYZ(rr,3)];
            thisETframe = headRotMat_row_col_fr(:,:,rr) * thisET_frame_unrot;
            
            
            lGazeXYZ(rr,:) = thisETframe;
            
        end
        
        % add the eyeball center (in shadow/world coordiates) to translate origin of gaze vector onto the shadow eyeball
        lGazeXYZ(:,1) = lGazeXYZ(:,1)+ lEyeballCenterXYZ(:,1);
        lGazeXYZ(:,2) = lGazeXYZ(:,2)+ lEyeballCenterXYZ(:,2);
        lGazeXYZ(:,3) = lGazeXYZ(:,3)+ lEyeballCenterXYZ(:,3);
        
        
        % Once more for the worldEyeCamera gaze vecotr
        
        %normalize its length
        for ll = 1:length(wGazeXYZ)
            wGazeXYZ(ll,:) = wGazeXYZ(ll,:)/norm(wGazeXYZ(ll,:));
        end
        
        %multiply it by your desired length ;)
        calibDist = pdist([worldCamCenterXYZ(calibFrame,:); calibPoint]); %myboy pythag
        wGazeXYZ = wGazeXYZ*calibDist*10;
        
        for rr = 1:length(wGazeXYZ)
            
            thisET_frame_unrot = wEyeAlignRotMat * [wGazeXYZ(rr,1); wGazeXYZ(rr,2); wGazeXYZ(rr,3)];
            thisETframe = headRotMat_row_col_fr(:,:,rr) * thisET_frame_unrot;
            
            
            wGazeXYZ(rr,:) = thisETframe;
            
        end
        
        % add the worldCamera center (in shadow/world coordiates) to translate origin of gaze vector onto the shadow eyeball
        wGazeXYZ(:,1) = wGazeXYZ(:,1)+ worldCamCenterXYZ(:,1);
        wGazeXYZ(:,2) = wGazeXYZ(:,2)+ worldCamCenterXYZ(:,2);
        wGazeXYZ(:,3) = wGazeXYZ(:,3)+ worldCamCenterXYZ(:,3);
        %% cull the weak! >:D
        
        confThresh = .85;
        rGazeXYZ(rEye_confidence < confThresh,:) = nan;
        lGazeXYZ(lEye_confidence < confThresh,:) = nan;
        %%  Calc Gaze/Ground intersections
        
        disp('calckin up some rGazeGroundIntersections')
        [ rGazeGroundIntersection] = calcGroundFixations( rHeelXYZ, lHeelXYZ, rGazeXYZ, rEyeballCenterXYZ );
        disp('calckin up some lGazeGroundIntersections')
        [ lGazeGroundIntersection] = calcGroundFixations( rHeelXYZ, lHeelXYZ, lGazeXYZ, lEyeballCenterXYZ );
        disp('calckin up some wGazeGroundIntersections')
        [ wGazeGroundIntersection] = calcGroundFixations( rHeelXYZ, lHeelXYZ, wGazeXYZ, worldCamCenterXYZ );
        
        %% Save out all the variables
        
        disp('Saving out mat file')
        cd(subPath)
        cd 'OutputFiles'
        save(strcat(condID,'.mat'))
        
    end
end

%% %%% make sphere thingy fr eyeball guys

sphRes = 20;
r = 35;%mean(rEye.sphere_radius); %p.s. it's 12mm, but let's blow 'em up a bit for ... visibilitiy... 8D
[th, phi] = meshgrid(linspace(0, 2*pi, sphRes), linspace(-pi, pi, sphRes));
[x1,y1,z1] = sph2cart(th, phi, r);

normScale = calibDist;
plotSkel = true;

lLeg = [2 3 4 5 6 7 5];
rLeg = [2 8 9 10 11 12 10];
tors = [2 13 14 15 26 27 28];
lArm = [15 16 17 26 17 18 19 20];
rArm = [15 21 22 26 22 23 24 25];

comXYZ = squeeze(shadow_fr_mar_dim(:,1,:));

frames = walks(5,1):10:walks(5,2);
% frames = vorFrames(1):10:vorFrames(end);


%build up the hypothetical groundplane
% plot (hypothetical) groundplane

xSpan = [min(rGazeGroundIntersection(frames,1))-5000, max(rGazeGroundIntersection(frames,1))+5000];
zSpan = [min(rGazeGroundIntersection(frames,3))-5000, max(rGazeGroundIntersection(frames,3))+5000];


res      = 100; % resultion for the meshgrid
[groundPlane_x, groundPlane_z] = meshgrid(xSpan(1):res:xSpan(2), zSpan(1):res:zSpan(2));


groundPlane_y = ones(size(groundPlane_x));
groundPlane_color = ones(size(groundPlane_x));




figure(1254);clf
% set(gcf,'Position',[1921 121 1920 979])



for ii = frames
    ii
    cla
    clf
    %%eyeball centers in shadow coordinats(not to be confused with "rEye_sphCen_x", which are in pupil camera coords)
    rEx = rEyeballCenterXYZ(ii,1);
    rEy = rEyeballCenterXYZ(ii,2);
    rEz = rEyeballCenterXYZ(ii,3);
    
    lEx = lEyeballCenterXYZ(ii,1);
    lEy = lEyeballCenterXYZ(ii,2);
    lEz = lEyeballCenterXYZ(ii,3);
    
    
    wEx = worldCamCenterXYZ(ii,1);
    wEy = worldCamCenterXYZ(ii,2);
    wEz = worldCamCenterXYZ(ii,3);
    
    %%pull out the l and r eye sphere centers for this frame
    rCx = rEye_sphCenCam_x(ii);
    rCy = rEye_sphCenCam_y(ii);
    rCz = rEye_sphCenCam_z(ii);
    
    lCx = lEye_sphCenCam_x(ii);
    lCy = lEye_sphCenCam_y(ii);
    lCz = lEye_sphCenCam_z(ii);
    
    
    grHeight(ii) = min([rHeelXYZ(ii,2) lHeelXYZ(ii,2) ]);
    
    % right eye
    r1 =  mesh(x1+rEx, y1+rEy, z1+rEz);
    r1.FaceColor = [1 .9 .9];
    r1.EdgeColor = 'k';
    r1.EdgeAlpha = 0.1;
    hold on
    
    
    %%% Plot circular patch for pupil - centered on pupilNorm (code jacked from - https://www.mathworks.com/matlabcentral/fileexchange/26588-plot-circle-in-3d)
    thisRPupCenter = [rEye_pupCircCen_x(ii)-rCx rEye_pupCircCen_y(ii)-rCy rEye_pupCircCen_z(ii)-rCz] ;
    thisRPupNormal = thisRPupCenter*normScale;
    thisRPupRadius = rEye_pupRadius(ii);
    
    if ~isnan(thisRPupNormal)
        theta=0:.1:2*pi;
        v=null(thisRPupNormal);
        points=repmat(thisRPupCenter',1,size(theta,2))+thisRPupRadius*(v(:,1)*cos(theta)+v(:,2)*sin(theta));
        patch(points(1,:)+rEx, points(2,:)+rEy, points(3,:)+rEz ,'r');
    end
    %%%%
    %
    %     plot3([0+rEx thisRPupCenter(1)+rEx],...
    %         [0+rEy thisRPupCenter(2)+rEy],...
    %         [0+rEz thisRPupCenter(3)+rEz],'k-','LineWidth',2)
    %
    %
    %     plot3([rEx thisRPupNormal(1)+rEx],...
    %         [rEy thisRPupNormal(2)+rEy],...
    %         [rEz thisRPupNormal(3)+rEz],'m-')
    %
    %     plot3([ thisRPupNormal(1)*normScale+rEx],...
    %         [ thisRPupNormal(2)*normScale+rEy],...
    %         [r thisRPupNormal(3)*normScale+rEz],'kp')
    
    plot3([rEx rGazeXYZ(ii,1)],...
        [rEy rGazeXYZ(ii,2)],...
        [rEz rGazeXYZ(ii,3)], 'm-','LineWidth',2)
    
    plot3(rGazeGroundIntersection(ii,1),...
        rGazeGroundIntersection(ii,2),...
        rGazeGroundIntersection(ii,3),'kp','MarkerFaceColor','r','MarkerSize',12)
    
    %     plot3(rGazeGroundIntersection(frames,1),...
    %         rGazeGroundIntersection(frames,2),...
    %         rGazeGroundIntersection(frames,3),'-r')
    
    
    % left eye
    l1 =  mesh(x1+lEx, y1+lEy, z1+lEz);
    l1.FaceColor = [.9 .9 1];
    l1.EdgeColor = 'none';
    
    hold on
    
    
    %%% Plot circular patch for pupil - centered on pupilNorm (code jacked from - https://www.mathworks.com/matlabcentral/fileexchange/26588-plot-circle-in-3d)
    thisLPupCenter = [lEye_pupCircCen_x(ii)-lCx lEye_pupCircCen_y(ii)-lCy lEye_pupCircCen_z(ii)-lCz] ;
    thisLPupNormal = thisLPupCenter*1.3;
    thisLPupRadius = lEye_pupRadius(ii);
    
    if ~isnan(thisLPupNormal)
        theta=0:.1:2*pi;
        v=null(thisLPupNormal);
        points=repmat(thisLPupCenter',1,size(theta,2))+thisLPupRadius*(v(:,1)*cos(theta)+v(:,2)*sin(theta));
        patch(points(1,:)+lEx, points(2,:)+lEy, points(3,:)+lEz ,'b');
    end
    %%%%
    
    %     plot3([0+lEx thisLPupCenter(1)+lEx],...
    %         [0+lEy thisLPupCenter(2)+lEy],...
    %         [0+lEz thisLPupCenter(3)+lEz],'k-','LineWidth',2)
    %
    %
    %     plot3([lEx thisLPupNormal(1)*normScale+lEx],...
    %         [lEy thisLPupNormal(2)*normScale+lEy],...
    %         [lEz thisLPupNormal(3)*normScale+lEz],'c-','LineWidth',2)
    %
    %     plot3([thisLPupNormal(1)*normScale+lEx],...
    %         [thisLPupNormal(2)*normScale+lEy],...
    %         [thisLPupNormal(3)*normScale+lEz],'kp')
    
    plot3([lEx lGazeXYZ(ii,1)],...
        [lEy lGazeXYZ(ii,2)],...
        [lEz lGazeXYZ(ii,3)], 'c-','LineWidth',2)
    
    plot3(lGazeGroundIntersection(ii,1),...
        lGazeGroundIntersection(ii,2),...
        lGazeGroundIntersection(ii,3),'kp','MarkerFaceColor','b','MarkerSize',12)
    
    %     plot3(lGazeGroundIntersection(frames,1),...
    %         lGazeGroundIntersection(frames,2),...
    %         lGazeGroundIntersection(frames,3),'-b')
    
    
    
    plot3([wEx wGazeXYZ(ii,1)],...
        [wEy wGazeXYZ(ii,2)],...
        [wEz wGazeXYZ(ii,3)], 'k-','LineWidth',2)
    
    plot3(wGazeGroundIntersection(ii,1),...
        wGazeGroundIntersection(ii,2),...
        wGazeGroundIntersection(ii,3),'kp','MarkerFaceColor','k','MarkerSize',12)
    
    
    plot3(calibPoint(1), calibPoint(2), calibPoint(3),'kp','MarkerSize',16,'MarkerFaceColor','y')
    
    
    
    
    if plotSkel
        %%%Plotcherself a skeleetoon
        plot3(shadow_fr_mar_dim(ii,1:28,1),shadow_fr_mar_dim(ii,1:28,2),shadow_fr_mar_dim(ii,1:28,3),'ko','MarkerFaceColor','k','MarkerSize',4)
        hold on
        
        
        plot3(shadow_fr_mar_dim(ii,lLeg,1),shadow_fr_mar_dim(ii,lLeg,2),shadow_fr_mar_dim(ii,lLeg,3),'c','LineWidth',2)
        plot3(shadow_fr_mar_dim(ii,rLeg,1),shadow_fr_mar_dim(ii,rLeg,2),shadow_fr_mar_dim(ii,rLeg,3),'r','LineWidth',2)
        plot3(shadow_fr_mar_dim(ii,tors,1),shadow_fr_mar_dim(ii,tors,2),shadow_fr_mar_dim(ii,tors,3),'g','LineWidth',2)
        plot3(shadow_fr_mar_dim(ii,lArm,1),shadow_fr_mar_dim(ii,lArm,2),shadow_fr_mar_dim(ii,lArm,3),'c','LineWidth',2)
        plot3(shadow_fr_mar_dim(ii,rArm,1),shadow_fr_mar_dim(ii,rArm,2),shadow_fr_mar_dim(ii,rArm,3),'r','LineWidth',2)
        
        %plot head axes
        hx = shadow_fr_mar_dim(ii,28,1);
        hy = shadow_fr_mar_dim(ii,28,2);
        hz = shadow_fr_mar_dim(ii,28,3);
        
        plot3([ hx headVecX_fr_xyz(ii,1)*1000+hx], [hy headVecX_fr_xyz(ii,2)*1000+hy],[hz headVecX_fr_xyz(ii,3)*1000+hz],'r-','LineWidth',3)
        plot3([ hx headVecY_fr_xyz(ii,1)*1000+hx], [hy headVecY_fr_xyz(ii,2)*1000+hy],[hz headVecY_fr_xyz(ii,3)*1000+hz],'g-','LineWidth',3)
        plot3([ hx headVecZ_fr_xyz(ii,1)*1000+hx], [hy headVecZ_fr_xyz(ii,2)*1000+hy],[hz headVecZ_fr_xyz(ii,3)*1000+hz],'b-','LineWidth',3)
        
        bx =   shadow_fr_mar_dim(ii,1,1);
        by =   shadow_fr_mar_dim(ii,1,2);
        bz =   shadow_fr_mar_dim(ii,1,3);
        
        %%% plot foothold locations
        rFootholds = steps_HS_TO_StanceLeg_XYZ(steps_HS_TO_StanceLeg_XYZ(:,3) == 1 ,:);
        lFootholds = steps_HS_TO_StanceLeg_XYZ(steps_HS_TO_StanceLeg_XYZ(:,3) == 2 ,:);
        
        rFootholds(rFootholds(:,1)<frames(1)| rFootholds(:,1)>frames(end),:) = [];
        lFootholds(lFootholds(:,1)<frames(1) | lFootholds(:,1)>frames(end),:) = [];
        
        %   plot vertical projection of foothold locations onto groundplane
        
        plot3(rFootholds(:,4), ones(length(rFootholds(:,1)))*grHeight(ii), rFootholds(:,6),'ko','MarkerSize', 9, 'MarkerFaceColor','r')
        plot3(lFootholds(:,4), ones(length(lFootholds(:,1)))*grHeight(ii), lFootholds(:,6),'ko','MarkerSize', 9, 'MarkerFaceColor','c')
        
        
        %plot gaussianly burnt groundplane
        sigma = 7500;
        meanGazeGround = mean([lGazeGroundIntersection(ii,:); rGazeGroundIntersection(ii,:)]);
        gaussian        = 1./sqrt(2*pi*sigma).*exp(-1./(2*sigma).*( (groundPlane_z-meanGazeGround(3)).^2 + (groundPlane_x-meanGazeGround(1)).^2));
        gaussianNorm    = gaussian ./ max(max(gaussian));
        
        if ~isnan(gaussianNorm)
            groundPlane_color = groundPlane_color + gaussianNorm; %add 2d gaussian for this frame's gaze/ground intersection ground plane
        end
        
        %         g_x = meshgrid(-10e4:500:10e4) + comXYZ(ii,1);
        %         g_y = ones(size(g_x)) * min([rHeelXYZ(ii,2) lHeelXYZ(ii,2) ]);
        %         g_z = meshgrid(-10e4:500:10e4)' + comXYZ(ii,3);
        
        s1 = surface(groundPlane_x , groundPlane_y*grHeight(ii), groundPlane_z, groundPlane_color  );
        s1.LineStyle = 'none';
        s1.FaceColor = 'interp';
        
        %         CT = cbrewer('div', 'Spectral', 64);
        %         colormap(flipud(CT));
        colormap jet
        caxis([0 10])
        
    end
    %     view(-173, -43);
    axis equal
    title(num2str(ii))
    %     set(gca,'CameraUpVector',[0 1 0])
    xlabel('x');ylabel('y'); zlabel('z');
    %     axis([-5000+bx 5000+bx -5000+by 5000+by -5000+bz 5000+bz])
    
    a = gca;
    a.CameraTarget = [comXYZ(ii,1), comXYZ(ii,2), comXYZ(ii,3)]; %point figure 'camera' at COM
    a.CameraPosition = a.CameraTarget + [-2800 2800 3000]; %set camera position
    a.CameraViewAngle = 80;
    a.CameraUpVector = [ 0 1 0];
    a.Position = [0 0 1 1];
    
    hold off
    drawnow
    
end

