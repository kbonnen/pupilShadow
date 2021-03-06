function playLaserSkeletonAndVideo(w)
recordVid = false;

    if ispc
        basePath = 'E:\Dropbox\UTexas\OpticFlowProject\';
        cd(basePath)
    elseif ismac
        basePath = '/Users/matthis/Dropbox/UTexas/OpticFlowProject/';
        cd(basePath)
    end

if recordVid
    vidObj = VideoWriter(strcat(basePath,'LaserSkeleton'),'MPEG-4');    
    open(vidObj)
end

shadow_fr_mar_dim = w.shadow_fr_mar_dim;
calibDist = w.calibDist;
comXYZ = w.comXYZ;
camComXYZ(:,1) = smooth(comXYZ(:,1),21);
camComXYZ(:,2) = smooth(comXYZ(:,2),21);
camComXYZ(:,3) = smooth(comXYZ(:,3),21);

rGazeGroundIntersection = w.rGazeGroundIntersection;
lGazeGroundIntersection = w.lGazeGroundIntersection;

rEyeballCenterXYZ = w.rEyeballCenterXYZ;
lEyeballCenterXYZ = w.lEyeballCenterXYZ;

rHeelXYZ = w.rHeelXYZ;
lHeelXYZ = w.lHeelXYZ;

rGazeXYZ = w.rGazeXYZ;
lGazeXYZ = w.lGazeXYZ;

headVecX_fr_xyz = w.headVecX_fr_xyz;
headVecY_fr_xyz = w.headVecY_fr_xyz;
headVecZ_fr_xyz = w.headVecZ_fr_xyz;

subID = w.subID;
sessionID = w.sessionID;
condID = w.condID;

worldFrameIndex = w.worldFrameIndex; %the frame from the world video that most closely matches the current skel/eye frame

% porX = w.porX;
% porY = w.porY;
% porXvel = w.porXvel;
% porYvel = w.porYvel;

if ~w.isThisVORCalibrationData
    steps_HS_TO_StanceLeg_XYZ = w.steps_HS_TO_StanceLeg_XYZ;
else
    steps_HS_TO_StanceLeg_XYZ =[nan nan nan nan nan nan];
end

%% set up videos

    %% find frame in eye videos that corresponds to each world frame

    if ismac
        imPath = strcat('/Volumes/sg4tb/FlowNet/',subID,'_',condID,'_im');
    elseif ispc
        imPath = strcat('F:\FlowNet',filesep,subID,'_',condID,'_im');
        eye0path =  strcat('F:\FlowNet',filesep,subID,'_',condID,'_eye0');
        eye1path =  strcat('F:\FlowNet',filesep,subID,'_',condID,'_eye1');
    end
    
    worldImages = imageDatastore(imPath);
    disp('eye0 images')
    eye0imagestore = imageDatastore(eye0path);
    disp('eye1 images')
    eye1imagestore = imageDatastore(eye1path);
    
    %% %%% find frame in eye videos that corresponds to each world frame
    disp('find frame in eye videos that corresponds to each world frame')
    
    cd(strcat(basePath,filesep,'Data',filesep,sessionID,filesep,condID,'/Pupil/'))
    e0timestamps = readNPY('eye0_timestamps.npy');
    e1timestamps = readNPY('eye1_timestamps.npy');
    worldTimestamps = readNPY('world_timestamps.npy');
    
    eye0index = nan(size(worldTimestamps));
    eye1index = nan(size(worldTimestamps));
    
    for ww = 1:length(worldFrameIndex)
        [~, eye0index(ww)] = min(abs(worldTimestamps(worldFrameIndex(ww)) - e0timestamps));
        [~, eye1index(ww)] = min(abs(worldTimestamps(worldFrameIndex(ww)) - e1timestamps));
    end
    %%
    
    
    
    pxPerDeg = 18.33;
    
    thisFrameRaw = readimage(worldImages, 1);
    height = size(thisFrameRaw,1);
    width = size(thisFrameRaw,2);
    
    porX = w.world_norm_pos_x * width;
    porY = height - w.world_norm_pos_y * height; %gotta do this weirdness to porY b/c of image vs XY coordinates
    
    porY(isnan(porY)) = 0;
    porX(isnan(porX)) = 0;
    
    porXdisp = porX - nanmean(porX);
    porYdisp = ((-porY)-nanmean(-porY)); %do some flippidoo nonsense to porY to make the trace look right (e.g. "downward saccades" correspond to the pupil moving downward)
    porXdisp = porXdisp./pxPerDeg;
    porYdisp = porYdisp./pxPerDeg;
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


frames = 1:4:length(comXYZ);
% plot (hypothetical) groundplane

xSpan = [min(rGazeGroundIntersection(frames,1))-5000, max(rGazeGroundIntersection(frames,1))+5000];
zSpan = [min(rGazeGroundIntersection(frames,3))-5000, max(rGazeGroundIntersection(frames,3))+5000];


res      = 100; % resultion for the meshgrid
[groundPlane_x, groundPlane_z] = meshgrid(xSpan(1):res:xSpan(2), zSpan(1):res:zSpan(2));


groundPlane_y = ones(size(groundPlane_x));
groundPlane_color = ones(size(groundPlane_x));



close all
figure(1254);clf
f = gcf;
f.Position = [1 41 1920 1080];

t = [];



for fr = frames
    tic
    
    disp(strcat({'Fr#'},num2str(fr),{'-PROGRESS: '}, num2str(fr),'-of-',num2str(frames(end)),...
        '- time remaining ~',num2str((nanmean(t) * (length(frames)))/60 ),'mins - Mean Frame Dur ~',num2str(nanmean(t)),...
        '- RecordVidset to:',num2str(recordVid)))
    
    cla
    clf
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Plot Laser Skeleton
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    skel1 = axes('Position',[0, 1/3, .5 2/3]);
    
    %%eyeball centers in shadow coordinats(not to be confused with "rEye_sphCen_x", which are in pupil camera coords)
    rEx = rEyeballCenterXYZ(fr,1);
    rEy = rEyeballCenterXYZ(fr,2);
    rEz = rEyeballCenterXYZ(fr,3);
    
    lEx = lEyeballCenterXYZ(fr,1);
    lEy = lEyeballCenterXYZ(fr,2);
    lEz = lEyeballCenterXYZ(fr,3);
    
    %     %%pull out the l and r eye sphere centers for this frame
    %     rCx = rEye_sphCenCam_x(ii);
    %     rCy = rEye_sphCenCam_y(ii);
    %     rCz = rEye_sphCenCam_z(ii);
    %
    %     lCx = lEye_sphCenCam_x(ii);
    %     lCy = lEye_sphCenCam_y(ii);
    %     lCz = lEye_sphCenCam_z(ii);
    %
    
    grHeight(fr) = min([rHeelXYZ(fr,2) lHeelXYZ(fr,2) ]);
    
    % right eye
    r1 =  mesh(x1+rEx, y1+rEy, z1+rEz);
    r1.FaceColor = [1 .9 .9];
    r1.EdgeColor = 'k';
    r1.EdgeAlpha = 0.1;
    hold on
    
    
    %     %%% Plot circular patch for pupil - centered on pupilNorm (code jacked from - https://www.mathworks.com/matlabcentral/fileexchange/26588-plot-circle-in-3d)
    %     thisRPupCenter = [rEye_pupCircCenXYZ(ii,1)-rCx rEye_pupCircCenXYZ(ii,2)-rCy rEye_pupCircCenXYZ(ii,3)-rCz] ;
    %     thisRPupNormal = thisRPupCenter*normScale;
    %     thisRPupRadius = rEye_pupRadius(ii);
    %
    %     if ~isnan(thisRPupNormal)
    %         theta=0:.1:2*pi;
    %         v=null(thisRPupNormal);
    %         points=repmat(thisRPupCenter',1,size(theta,2))+thisRPupRadius*(v(:,1)*cos(theta)+v(:,2)*sin(theta));
    %         patch(points(1,:)+rEx, points(2,:)+rEy, points(3,:)+rEz ,'r');
    %     end
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
    
    plot3([rEx rGazeXYZ(fr,1)],...
        [rEy rGazeXYZ(fr,2)],...
        [rEz rGazeXYZ(fr,3)], 'm-','LineWidth',2)
    
    plot3(rGazeGroundIntersection(fr,1),...
        rGazeGroundIntersection(fr,2),...
        rGazeGroundIntersection(fr,3),'kp','MarkerFaceColor','r','MarkerSize',12)
    
    %     plot3(rGazeGroundIntersection(frames,1),...
    %         rGazeGroundIntersection(frames,2),...
    %         rGazeGroundIntersection(frames,3),'-r')
    
    
    % left eye
    l1 =  mesh(x1+lEx, y1+lEy, z1+lEz);
    l1.FaceColor = [.9 .9 1];
    l1.EdgeColor = 'none';
    
    hold on
    
    
    %     %%% Plot circular patch for pupil - centered on pupilNorm (code jacked from - https://www.mathworks.com/matlabcentral/fileexchange/26588-plot-circle-in-3d)
    %     thisLPupCenter = [lEye_pupCircCenXYZ(ii,1)-lCx lEye_pupCircCenXYZ(ii,2)-lCy lEye_pupCircCenXYZ(ii,3)-lCz] ;
    %     thisLPupNormal = thisLPupCenter*1.3;
    %     thisLPupRadius = lEye_pupRadius(ii);
    %
    %     if ~isnan(thisLPupNormal)
    %         theta=0:.1:2*pi;
    %         v=null(thisLPupNormal);
    %         points=repmat(thisLPupCenter',1,size(theta,2))+thisLPupRadius*(v(:,1)*cos(theta)+v(:,2)*sin(theta));
    %         patch(points(1,:)+lEx, points(2,:)+lEy, points(3,:)+lEz ,'b');
    %     end
    %     %%%%
    
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
    
    plot3([lEx lGazeXYZ(fr,1)],...
        [lEy lGazeXYZ(fr,2)],...
        [lEz lGazeXYZ(fr,3)], 'c-','LineWidth',2)
    
    plot3(lGazeGroundIntersection(fr,1),...
        lGazeGroundIntersection(fr,2),...
        lGazeGroundIntersection(fr,3),'kp','MarkerFaceColor','b','MarkerSize',12)
    
    %     plot3(lGazeGroundIntersection(frames,1),...
    %         lGazeGroundIntersection(frames,2),...
    %         lGazeGroundIntersection(frames,3),'-b')
    
    
    if plotSkel
        %%%Plotcherself up a nice little skeleetoon friend
        plot3(shadow_fr_mar_dim(fr,1:28,1),shadow_fr_mar_dim(fr,1:28,2),shadow_fr_mar_dim(fr,1:28,3),'ko','MarkerFaceColor','k','MarkerSize',8)
        hold on
        
        
        plot3(shadow_fr_mar_dim(fr,lLeg,1),shadow_fr_mar_dim(fr,lLeg,2),shadow_fr_mar_dim(fr,lLeg,3),'c','LineWidth',4)
        plot3(shadow_fr_mar_dim(fr,rLeg,1),shadow_fr_mar_dim(fr,rLeg,2),shadow_fr_mar_dim(fr,rLeg,3),'r','LineWidth',4)
        plot3(shadow_fr_mar_dim(fr,tors,1),shadow_fr_mar_dim(fr,tors,2),shadow_fr_mar_dim(fr,tors,3),'g','LineWidth',4)
        plot3(shadow_fr_mar_dim(fr,lArm,1),shadow_fr_mar_dim(fr,lArm,2),shadow_fr_mar_dim(fr,lArm,3),'c','LineWidth',4)
        plot3(shadow_fr_mar_dim(fr,rArm,1),shadow_fr_mar_dim(fr,rArm,2),shadow_fr_mar_dim(fr,rArm,3),'r','LineWidth',4)
        
        %plot head axes
        hx = shadow_fr_mar_dim(fr,28,1);
        hy = shadow_fr_mar_dim(fr,28,2);
        hz = shadow_fr_mar_dim(fr,28,3);
        
        plot3([ hx headVecX_fr_xyz(fr,1)*100+hx], [hy headVecX_fr_xyz(fr,2)*100+hy],[hz headVecX_fr_xyz(fr,3)*100+hz],'r-','LineWidth',3)
        plot3([ hx headVecY_fr_xyz(fr,1)*100+hx], [hy headVecY_fr_xyz(fr,2)*100+hy],[hz headVecY_fr_xyz(fr,3)*100+hz],'g-','LineWidth',3)
        plot3([ hx headVecZ_fr_xyz(fr,1)*100+hx], [hy headVecZ_fr_xyz(fr,2)*100+hy],[hz headVecZ_fr_xyz(fr,3)*100+hz],'c-','LineWidth',3)
        
        bx =   shadow_fr_mar_dim(fr,1,1);
        by =   shadow_fr_mar_dim(fr,1,2);
        bz =   shadow_fr_mar_dim(fr,1,3);
        
        %%% plot foothold locations
        rFootholds = steps_HS_TO_StanceLeg_XYZ(steps_HS_TO_StanceLeg_XYZ(:,3) == 1 ,:);
        lFootholds = steps_HS_TO_StanceLeg_XYZ(steps_HS_TO_StanceLeg_XYZ(:,3) == 2 ,:);
        
        rFootholds(rFootholds(:,1)<fr-2000 | rFootholds(:,1)>fr+2000,:) = [];
        lFootholds(lFootholds(:,1)<fr-2000 | lFootholds(:,1)>fr+2000,:) = [];
        
        %   plot vertical projection of foothold locations onto groundplane
        
        plot3(rFootholds(:,4), ones(length(rFootholds(:,1)))*grHeight(fr), rFootholds(:,6),'ko','MarkerSize', 12, 'MarkerFaceColor','r')
        plot3(lFootholds(:,4), ones(length(lFootholds(:,1)))*grHeight(fr), lFootholds(:,6),'ko','MarkerSize', 12, 'MarkerFaceColor','c')
        
        
        %plot gaussianly burnt groundplane
        sigma = 7500;
        meanGazeGround = nanmean([lGazeGroundIntersection(fr,:); rGazeGroundIntersection(fr,:)]);
        gaussian        = 1./sqrt(2*pi*sigma).*exp(-1./(2*sigma).*( (groundPlane_z-meanGazeGround(3)).^2 + (groundPlane_x-meanGazeGround(1)).^2));
        gaussianNorm    = gaussian ./ max(max(gaussian));
        
        if ~isnan(gaussianNorm)
            groundPlane_color = groundPlane_color + gaussianNorm; %add 2d gaussian for this frame's gaze/ground intersection ground plane
        end
        
        %         g_x = meshgrid(-10e4:500:10e4) + comXYZ(ii,1);
        %         g_y = ones(size(g_x)) * min([rHeelXYZ(ii,2) lHeelXYZ(ii,2) ]);
        %         g_z = meshgrid(-10e4:500:10e4)' + comXYZ(ii,3);
        
        s1 = surface(groundPlane_x , groundPlane_y*grHeight(fr), groundPlane_z, groundPlane_color  );
        s1.LineStyle = 'none';
        s1.FaceColor = 'interp';
        
        %         CT = cbrewer('div', 'Spectral', 64);
        %         colormap(flipud(CT));
        colormap jet
        caxis([0 10])
        
    end
    %     view(-173, -43);
    axis equal
    title(num2str(fr))
    %     set(gca,'CameraUpVector',[0 1 0])
    xlabel('x');ylabel('y'); zlabel('z');
    %     axis([-5000+bx 5000+bx -5000+by 5000+by -5000+bz 5000+bz])
    
    a = gca;
    a.CameraTarget = [camComXYZ(fr,1), camComXYZ(fr,2), camComXYZ(fr,3)]; %point figure 'camera' at COM
    a.CameraPosition = a.CameraTarget + [-1800 1800 2000]; %set camera position
    a.CameraViewAngle = 80;
    a.CameraUpVector = [ 0 1 0];
    hold off
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% Plot (nearest) frame from World Camera
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    world1 = axes('Position',[0.5, 1/3, .5 2/3]);
    imshow(readimage(worldImages, worldFrameIndex(fr)))
    hold on
    plot([porX(fr) porX(fr)], [0 height],'-k', 'LineWidth',2)
    plot([0 width], [porY(fr) porY(fr)], '-k', 'LineWidth',2)
    viscircles([porX(fr) porY(fr)],pxPerDeg,'Color','k','EnhanceVisibility',false);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% show eyeballs  -> O_0 <-   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        imEye0 = readimage(eye0imagestore,eye0index(fr)); %right eye
        
        imEye1 = readimage(eye1imagestore,eye1index(fr)); % left eye
        
        eyeWidth = size(imEye0,2);
        eyeHeight = size(imEye0,1);
        
        ey1ax = axes;
        ey1ax.Position = [0.0500    0.022    0.16   0.2497];
        axis off
       imshow(fliplr(imEye1))
     
        ey0ax = axes;
        ey0ax.Position = [0.79    0.022    0.16   0.2497];
        axis off
        imshow(flipud(imEye0))
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% Plot POR/gaze traces
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    porWindow = 500;
    gzXAx = axes('Position',[0.2222 0.1307 0.5549 0.0805]);
    box on
    
    plot(porXdisp,'ro-','LineWidth',1,'MarkerSize',2);
    hold on
    
    plot( [ fr fr]+.3, [1000 -1000],'k-','LineWidth',2)
    
    plot(fr, porXdisp(fr),'ko','MarkerFaceColor','w');
    
    xlim([fr-porWindow fr+porWindow]);
    ylim([-10 10]);
    
    
    hold on
    
%     set(gca, 'XTick', []);
    set(gca, 'YTick', [-5 0 5]);
    grid on
    
    
    gzXlab1 = text(fr-145,-6,'Horizontal Eye-in-Head Position');
    gzXlab1.FontSize = 16;
    gzXlab1.Color = 'r';
    gzXlab1.FontWeight = 'bold';
    
    
    gzYAx = axes('Position',[0.2222 0.0494 0.5549 0.0805]);
    box on
    
    plot(porYdisp,'bo-','LineWidth',1,'MarkerSize',1);
    hold on
    
    plot( [ fr fr]+.3, [1000 -1000],'k-','LineWidth',2)
    
    plot(fr, porYdisp(fr),'ko','MarkerFaceColor','w');
    
    xlim([fr-porWindow fr+porWindow]);
    ylim([-10 10]);
    
    hold on
    
%     set(gca, 'XTick', []);
    set(gca, 'YTick', [-5 0 5]);
    grid on
    
    gzXlab1 = text(fr-145,-6,'Vertical Eye-in-Head Position');
    gzXlab1.FontSize = 16;
    gzXlab1.Color = 'b';
    gzXlab1.FontWeight = 'bold';
    
    
    
      drawnow
    
    
    
    if recordVid
        thisFrame = getframe(gcf);
        writeVideo(vidObj,thisFrame);
        
    end
    
    t(fr-frames(1)+1) = toc;
end

%%
if recordVid
    close(vidObj)
end
