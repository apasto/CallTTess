function out_gzz_misfit = IntrLayer(X,Y,Z,xsize,ysize,Rho,Z0,in_gzz,GrdFile,nObs)
%IntrLayer

Tess = IntrLayer_BuildTess(X,Y,Z,xsize,ysize,Rho,Z0);

% call CallTTess_AnyGrid
ParFlag = 0;
VerbFlag = 0;
CalcFlag = [0 0 0 0 0 0 0 0 0 1]; % [pot gx gy gz gxx gxy gxz gyy gyz gzz]
out_gzz = CallTTess_AnyGrid(...
    GrdFile,nObs,Tess,...
    ParFlag,VerbFlag,CalcFlag);

out_gzz_misfit = in_gzz - out_gzz;

end

% embedded function: build tesseroid-array
function Tess = IntrLayer_BuildTess(X,Y,Z,xsize,ysize,DeltaRho,Z0)
%UnderplatingF_BuildTess
% build tesseroids centered in (X,Y), (xsize,ysize) wide
% with top/bottom in Z
% CONTINUARE!

x1 = X - xsize/2;
x2 = X + xsize/2;
y1 = Y - ysize/2;
y2 = Y + ysize/2;

z1 = []; % TOP
z2 = []; % BOTTOM

Rho = [];

Tess = vertcat(x1,x2,y1,y2,z1,z2,Rho)';

end

