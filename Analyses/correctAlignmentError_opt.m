function  [thisWalk] = correctAlignmentError_opt(thisWalk_orig)


for iter = 1:2 % 1 = Right EYE, 2 = left eye
    %%
    if iter == 1
        gazeXYZ = thisWalk_orig.rGazeXYZ;
        camXYZ = thisWalk_orig.rEyeballCenterXYZ;
        
    elseif iter == 2
        gazeXYZ = thisWalk_orig.lGazeXYZ;
        camXYZ = thisWalk_orig.lEyeballCenterXYZ;
        
    end
    
walks = thisWalk_orig.walks;

    shadow_fr_mar_dim = thisWalk_orig.shadow_fr_mar_dim;
    shadowMarkerNames = thisWalk_orig.shadowMarkerNames;
    
    comXYZ = squeeze(thisWalk_orig.shadow_fr_mar_dim(:,1,:));
    
    
    %%
    
    frames = 1:length(comXYZ(walks(1,1):walks(1,2),:));
    
    rHeelXYZ = squeeze(shadow_fr_mar_dim(:,strcmp('RightHeel', shadowMarkerNames),:)); % pull out lHeel marker
    lHeelXYZ = squeeze(shadow_fr_mar_dim(:,strcmp('LeftHeel', shadowMarkerNames),:)); % pull out lHeel marker

    
    %%
    
    plotDebug = true;
    correctAlignmentLossFcn = @(w) correctAlignmentErrorFcn(gazeXYZ(walks(1,1):walks(1,2),:), comXYZ(walks(1,1):walks(1,2),:), camXYZ(walks(1,1):walks(1,2),:), rHeelXYZ(walks(1,1):walks(1,2),:), lHeelXYZ(walks(1,1):walks(1,2),:), frames, plotDebug, w);
    
    w0 = 0; %starting guess for theta
    
    if plotDebug == true
        opts = optimset('Display', 'iter', 'PlotFcns',{@optimplotx, @optimplotfval,@optimplotfirstorderopt});
    elseif plotDebug == false
        opts = optimset('Display', 'iter');
    end
    
    corrAlignTheta = fminunc(correctAlignmentLossFcn, w0, opts);
    
    
    
    
    %% get to rotatin'
    
    
    % gaze originating from camXYZ (inerial reference frame)
    g(:,1) = gazeXYZ(:,1)+camXYZ(:,1);
    g(:,2) = gazeXYZ(:,3)+camXYZ(:,3);
    
    
    % center g on comXYZ (comXYZ reference frame)
    g(:,1) = g(:,1)-comXYZ(:,1);
    g(:,2) = g(:,2)-comXYZ(:,3);
    
    %center camXYZ on comXYZ (comXYZ reference frame
    c(:,1) = camXYZ(:,1)-comXYZ(:,1);
    c(:,2) = camXYZ(:,3)-comXYZ(:,3);
    
    
    
    
    for rr = 1:length(g) %rotate gaze and cam by thetaGuess around their new origin (i.e. the COM)
        
        g(rr,1) = ...
            g(rr,1) * cos(corrAlignTheta)+... %x*cos(theta)
            g(rr,2) * sin(corrAlignTheta);    %y*sin(theta)
        
        g(rr,2) = ...
            -g(rr,1) * sin(corrAlignTheta)+... %x*cos(theta)
            g(rr,2) * cos(corrAlignTheta);    %y*sin(theta)
        
        
        
        c(rr,1) = ...
            c(rr,1) * cos(corrAlignTheta)+... %x*cos(theta)
            c(rr,2) * sin(corrAlignTheta);    %y*sin(theta)
        
        c(rr,2) = ...
            -c(rr,1) * sin(corrAlignTheta)+... %x*cos(theta)
            c(rr,2) * cos(corrAlignTheta);    %y*sin(theta)
        
        
        
    end
    
    
    
    % revert gaze to right coord system
    g(:,1) = g(:,1)+comXYZ(:,1);
    g(:,2) = g(:,2)+comXYZ(:,3);
    
    g(:,1) = g(:,1)-camXYZ(:,1);
    g(:,2) = g(:,2)-camXYZ(:,3);
    
    gazeXYZ(:,1) = g(:,1);
    gazeXYZ(:,3) = g(:,2);
    
    thisWalk_orig.gazeXYZ = gazeXYZ;
    
    % revert camXYZ to right coord system
    c(:,1) = c(:,1)+comXYZ(:,1);
    c(:,2) = c(:,2)+comXYZ(:,3);
    
    camXYZ(:,1) = c(:,1);
    camXYZ(:,3) = c(:,2);
    
    
    if iter == 1
        thisWalk_orig.rGazeXYZ = gazeXYZ;
        thisWalk_orig.rEyeballCenterXYZ = camXYZ;
        
    elseif iter == 2
        
        thisWalk_orig.lGazeXYZ = gazeXYZ;
        thisWalk_orig.lEyeballCenterXYZ = camXYZ;
    end
    
    
    
    % recalculate ground fixations
    
    rHeelID = find(strcmp('RightHeel', shadowMarkerNames));
    rHeelXYZ = squeeze(shadow_fr_mar_dim(:,rHeelID,:)); % pull out rHeelID marker
    
    rToeID = find(strcmp('RightToe', shadowMarkerNames));
    rToeXYZ = squeeze(shadow_fr_mar_dim(:,rToeID,:)); % pull out rHeelID marker
    
    lHeelID = find(strcmp('LeftHeel', shadowMarkerNames));
    lHeelXYZ = squeeze(shadow_fr_mar_dim(:,lHeelID,:)); % pull out rHeelID marker
    
    lToeID = find(strcmp('LeftToe', shadowMarkerNames));
    lToeXYZ = squeeze(shadow_fr_mar_dim(:,lToeID,:)); % pull out rHeelID marker000
    
    
    
    if iter == 1
        disp('calckin up some rGazeGroundIntersections')
        [ thisWalk_orig.rGazeGroundIntersection] = calcGroundFixations( rHeelXYZ, lHeelXYZ, gazeXYZ, camXYZ );
        thisWalk_orig.rCorrAlignTheta = corrAlignTheta;
    elseif iter == 2
        disp('calckin up some lGazeGroundIntersections')
        [ thisWalk_orig.lGazeGroundIntersection] = calcGroundFixations( rHeelXYZ, lHeelXYZ, gazeXYZ, camXYZ );
        thisWalk_orig.lCorrAlignTheta = corrAlignTheta;
    end
    
    
    
end

%% rotate shadow data


% zero everything (i.e. set origin to comXYZ)
for ff = 1:length(comXYZ)
    
    
    for mm = 1:numel(shadow_fr_mar_dim(1,:,1)) %m = Marker
        
        s(ff,mm,1) = shadow_fr_mar_dim(ff,mm,1) - comXYZ(ff,1);
        s(ff,mm,2) = shadow_fr_mar_dim(ff,mm,2) - comXYZ(ff,2);
        s(ff,mm,3) = shadow_fr_mar_dim(ff,mm,3) - comXYZ(ff,3);
    end
    
end




%rotate gaze and cam by thetaGuess around their new origin (i.e. the COM)
for rr = 1:length(comXYZ)
    
    for mm = 1:numel(shadow_fr_mar_dim(1,:,1)) %m = Marker
        
        s(rr,mm,1) = ...
            s(rr,mm,1) * cos(corrAlignTheta)+... %x*cos(theta)
            s(rr,mm,3) * sin(corrAlignTheta);    %y*sin(theta)
        
        s(rr,mm,3) = ...
            -s(rr,mm,1) * sin(corrAlignTheta)+... %x*cos(theta)
            s(rr,mm,3) * cos(corrAlignTheta);    %y*sin(theta)
    end
end

%do, like, the opposite of zero-ing (i.e. put te shadow dat back into inertial frame)
for ff = 1:length(comXYZ)
    
    
    for mm = 1:numel(shadow_fr_mar_dim(1,:,1)) %m = Marker
        
        s(ff,mm,1) = s(ff,mm,1) + comXYZ(ff,1);
        s(ff,mm,2) = s(ff,mm,2) + comXYZ(ff,2);
        s(ff,mm,3) = s(ff,mm,3) + comXYZ(ff,3);
    end
    
end

thisWalk_orig.shadow_ds_fr_mar_dim = s;


thisWalk_orig.corrAlignTheta = corrAlignTheta;
thisWalk = thisWalk_orig;



