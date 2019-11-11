function PrismPathDef = CallTPrism_GetPath
%CallTPrism
% provides a 'PrismPathDef' structure
% containing the following fields:
%     - TessPath : path to Tesseroids binaries
%     - TessGrd  : name of tessgrd binary (used also for prisms)
%     - ExeNames : names of functionals (prismg*) binaries
% these are defined by the 'CallTTess_DefinePath' function
% which saves a 'PrismPathDef.mat' file in the same directory of this file
narginchk(0,0)
nargoutchk(1,1)

% get path of CallTTess (fine for prisms)
CallTTess_path = which('CallTTess');
CallTTess_path = CallTTess_path(1:end-length('CallTTess.m'));

assert(...
    isfile([CallTTess_path,'TessPathDef.mat']),...
    ['PrismPathDef.mat does not exist in ',CallTTess_path,...
    ' Create it using CallTTess_DefinePath']);

load([CallTTess_path,'PrismPathDef.mat'],'PrismPathDef');

end

