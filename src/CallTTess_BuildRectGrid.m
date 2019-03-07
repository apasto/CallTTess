function CallTTess_BuildRectGrid(xmin,xmax,xnum,ymin,ymax,ynum,h,TmpGrdFile,grdBuilder,varargin)
%CallTTess_BuildRectGrid
nargoutchk(0,0)
narginchk(9,11)

% default precision: up to 5 decimal digits
DefaultWritePrec = '%.5f';
if nargin>=10
    if and(ischar(varargin{1}),~isempty(varargin{1}))
        WritePrec = varargin{1};
    else
        WritePrec = DefaultWritePrec;
    end
else
    WritePrec = DefaultWritePrec;
end

% get reference ellipsoid, if provided (needed if grdBuilder is TessGrdEll)
if nargin==11
    Ell_ref = varargin{2};
end

% calling tessgrd, it is way faster to write to a file and read from it
switch grdBuilder
    case 'tessgrd'
        [GrdStatus,GrdCmdout] = system([TessPathDef.TessPath,TessPathDef.TessGrd,' -v -r',...
                                        num2str(xmin,WritePrec),'/',num2str(xmax,WritePrec),'/',...
                                        num2str(ymin,WritePrec),'/',num2str(ymax,WritePrec),' -b',...
                                        num2str(xnum,WritePrec),'/',num2str(ynum,WritePrec),...
                                        ' -z',num2str(h,WritePrec),' > ',TmpGrdFile]);
        if GrdStatus~=0
            disp(['Output of system call to ',TessPathDef.TessGrd]);
            disp(GrdCmdout);
            error([TessPathDef.TessGrd,' exited with nonzero status. Quitting.']);
        end
    case 'TessGrdEll'
        xstep = (xmax-xmin)/(xnum-1);
        ystep = (ymax-ymin)/(ynum-1);
        TessGrdEll(TmpGrdFile,ymin,ymax,ystep,xmin,xmax,xstep,h,Ell_ref)
end

end

% embedded function: TessGrdEll
function TessGrdEll(TargetFile,LatMin,LatMax,LatStep,LonMin,LonMax,LonStep,Height,Ell_ref)
%TessGrdEll Build Tesseroid grid defined in ellipsoidal coords, then
%           converted to spherical coords and height respect to equatorial radius
%   TessGrdEll(TargetFile,LatMin,LatMax,LatStep,LonMin,LonMax,LonStep,Height,Ell_ref)

nargoutchk(0,0)
narginchk(9,9)

% referenceSphere: hardcoded to Tesseroids, equatorial radius
Sph_ref = referenceSphere('earth');
Sph_ref.Radius = 6378137; % from src/lib/constant.c in Tesseroids 1.2.1

% Build regular grid
% longitudes do not need ell2sph transformation
LonV = LonMin:LonStep:LonMax;

Ell_LatV = LatMin:LatStep:LatMax;
% transform latitudes into spherical latitudes
[Sph_LatV,~,Sph_HeightsV] = ell2sph(Ell_LatV,zeros(size(Ell_LatV)),ones(size(Ell_LatV))*Height,...
                                    Ell_ref,Sph_ref);

[Sph_Mesh_Lon,Sph_Mesh_Lat] = meshgrid(LonV,Sph_LatV);
Sph_Mesh_Heights = Sph_HeightsV' * ones(size(LonV));

% Open file
TargetFileID = fopen(TargetFile,'w');
% create onCleanup object, to fclose whatever happens
onCleanupTargetFile = onCleanup(@() GrdCloseFile(TargetFileID));

% Write header
% 5 rows, as in tessgrd output
HeaderText = ['# Grid generated with TessGrdEll.m:\n',...
              '#   local time: ',datestr(now,'yyyy-mm-dd HH:MM:ss\n'),...
              '#   ell(Lat min=',num2str(LatMin),' max=',num2str(LatMax),')',...
                 ' sph(Lat min=',num2str(min(Sph_LatV)),' max=',num2str(max(Sph_LatV)),')',...
                 ' Lon min=',num2str(LonMin),' max=',num2str(LonMax),...
                 ' ell_h=',num2str(Height),' ell=',Ell_ref.Name,'\n',...
              '#   grid spacing: ',num2str(LonStep),' lon / ',num2str(LatStep), ' lat\n',...
              '#   grid size: ',num2str(size(Sph_Mesh_Lon,1),'%u'),' x ',num2str(size(Sph_Mesh_Lon,2),'%u'),...
                 ', total ',num2str(numel(Sph_Mesh_Lon),'%d'),' points\n'];
fprintf(TargetFileID,HeaderText);

% Write in Tesseroids calculation point format
% 5 decimal digits precision deemed enough for purpose
formatSpec = strcat(repmat([WritePrec,' '],1,3),'\n');
fprintf(TargetFileID,formatSpec,...
        [Sph_Mesh_Lon(:),Sph_Mesh_Lat(:),Sph_Mesh_Heights(:)]');

% fclose(TargetFileID) is not needed, since there is a onCleanup object

end

% Cleanup function called when cleanup objects are destroyed
% this happens on normal completition
% or due to errors, Ctrl+C by user, unforeseeable disasters, etc

function GrdCloseFile(Target)
fclose(Target);
end
