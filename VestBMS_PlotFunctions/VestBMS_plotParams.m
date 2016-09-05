function minq = VestBMS_plotParams(nids,modelfamily,joint,noplot,poolflag)
%VESTBMS_PLOTPARAMS Plot and compare parameters from different tasks.

if nargin < 2 || isempty(modelfamily); modelfamily = 'bayes'; end
if nargin < 3 || isempty(joint); joint = 0; end
if nargin < 4 || isempty(noplot); noplot = 0; end
if nargin < 5 || isempty(poolflag); poolflag = 0; end

switch(lower(modelfamily(1)))
    case 'b';           % Bayesian
        % modeln = [2 10 6 2];
        modelnames = {'BP','BPD','BPD','BPD'};
        family = 'Bayesian';
    case {'f','c'};     % Fixed criterion
        % modeln = [2 8 5 1];
        modelnames = {'BP','CXD','CX','CXD'};
        family = 'Fixed';
    otherwise
        error('Unknown model family. Known families are (B)ayesian and (F)ixed criterion.');
end

if joint
    fitnames = {'uni','biml','bimu','joint'};
else
    fitnames = {'uni','biml','bimu'};
    % modeln = modeln(2:3);
    % fitnames = {'biml','bimu'};
end

fprintf('Compare parameters from the %s model family.\n', upper(family));

mbags = load('VestBMS_modelfits.mat');

ids = 1:11; % Human only

for i = 1:numel(fitnames)
    mbag = mbags.(['mbag_' fitnames{i}]);
    modelsummary = mbags.(['modelsummary_' fitnames{i}]);
    modeln = find(strcmp(modelnames{i},modelsummary.modelnames));
    if isempty(modeln) || ~isscalar(modeln)
        error(['Error in finding model ' modelnames{i} ' (no matches or multiple matches).']);
    end
    mfits{i} = ModelBag_get(mbag,modelsummary.dataid(ids,:),modelsummary.models(modeln,:),modelsummary.cnd);
end

if poolflag
    for i = 1:numel(mfits)
        for j = 2:numel(mfits{i})
            mfits{i}{1}.sampling.samples = ...
                [mfits{i}{1}.sampling.samples; mfits{i}{j}.sampling.samples];
        end
    end    
    nids = 1;
end

for i = 1:numel(nids)
    if ~noplot; figure; end
    nid = nids(i);
    switch numel(mfits)
        case 2
            minq(i,:) = ModelPlot_plotParameters('VestBMS',...
                mfits{1}{nid},mfits{2}{nid},noplot);
        case 3
            minq(i,:) = ModelPlot_plotParameters('VestBMS',...
                mfits{1}{nid},mfits{2}{nid},mfits{3}{nid},noplot);
        case 4
            minq(i,:) = ModelPlot_plotParameters('VestBMS',...
                mfits{1}{nid},mfits{2}{nid},mfits{3}{nid},mfits{4}{nid},noplot);
    end
end


end