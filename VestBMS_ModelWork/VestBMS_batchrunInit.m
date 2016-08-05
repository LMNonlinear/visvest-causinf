function [options,models,dataids,cnd] = VestBMS_batchrunInit(data,type,options)
% VESTBMS_BATCHRUNINIT initialize variables for batch run.

if nargin < 3; options = []; end

debug = 0;

% Get additional type parameters
type = type(1);

% Trials are binned for computation of the log likelihood (obsolete!)
% options = setoptions(options,'binnedloglik',1,1);

% Continue previous sampling if exists
options = setoptions(options,'loadstartx',1,1);

% Slice sampling window multiplier
options = setoptions(options,'samplingtemperature',1,1);

% By default do not compute Hessian unless optimizing (see below)
options = setoptions(options,'hessianflag',0,1);

options = setoptions(options,'optimizationmethod','bps',1);
% options = setoptions(options,'optimizationmethod','fmincon',1);

% Get host name
[~,hostname] = system('hostname');
options = setoptions(options,'hostname',strtrim(hostname),1);

% Number of datasets
if isfield(data,'data'); nDatasets = length(data.data);
else nDatasets = length(data); end

% Subjects mask
DATAIDS = [(1:nDatasets)',zeros(nDatasets,1)];

% Default number of samples for unimodal/bimodal trials
NSAMPLES = [1e4,5e3];
NSAMPLES = [0 0];

% Default optimization steps before starting sampling
MAXFUNEVALS = 1500;

% Optimization steps when optimizing only
NITER_OPTIMIZATION = 1500;

% Number of restarts for optimization
% nOptimizationRestarts = 50;
nOptimizationRestarts = 10;

if debug
    nOptimizationRestarts = 10;
    NSAMPLES = [10,10];
    MAXFUNEVALS = 10;
end

options = setoptions(options,'nstarts',nOptimizationRestarts,1);
options = setoptions(options,'nsobol',1e4,1);
options = setoptions(options,'optfevals',MAXFUNEVALS,1);
if isempty(options.optfevals); options.optfevals = MAXFUNEVALS; end

dataids = DATAIDS;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DEFAULT MODELS

models = [];
standardunimodalmodels = [ ...
    5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 1 1 0; ... % Base
    ];

%unimodal2bimodalmodels = [ ...
%    5 3 1 1, 1 1 1 3, 1 1 2 1, 1 1 2 1 0; ... %  1 MEAN and Gaussian noise/likelihood
%    ];



% Best unimodal models
bestunimodalmodels = [ ...
    4 2 1 5, 5 1 2 5, 1 2 1 2, 2 1 1 1 0; ... %  9 MEAN and quadratic Gaussian noise/spatially-constant-likelihood (single w)
    ];

% Standard bimodal models
standardbimodalmodels = [ ...
    5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 2 1 0; ... % Generalized Bayesian
    5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 4 1 0; ... % Soft fixed criterion
    5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 5 1 0; ... % Forced fusion
    ];


switch type
    case 0; % DEBUG    
        
        [options,models,groupcnd] = VestBMS(options,2,0);
        options.jobname = 'vest_debug';
        dataids = [1 0];
        
        options = setoptions(options,'nsamples',100,1);
        options = setoptions(options,'nstoredsamples',15,1);
        options = setoptions(options,'optfevals',20,1);
        options = setoptions(options,'nstarts',1,1);
        models = models(1,:);
        
%--------------------------------------------------------------------------        
% BISENSORY ESTIMATION DATA FITS
    
   case {1} % Bisensory standard models
        
       [options,models,groupcnd] = VestBMS(options,2,0);
       options.jobname = 'vest_bim';
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials
       
    case 2  % Monkey only
       [options,models,groupcnd] = VestBMS(options,2,0);
       options.jobname = 'vest_bim_monkey';
       dataids = [12 8; 13 8; 14 8];
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials

   case {11} % Bisensory standard models without beta
        
       [options,models,groupcnd] = VestBMS(options,2,0);
       options.jobname = 'vest_2bim';
       models(:,11) = 3;    % Probability matching
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials

   case {21} % Bisensory standard models without beta and with lapse
       
       [options,models,groupcnd] = VestBMS(options,2,0);
       options.jobname = 'vest_lbim';
       models(:,11) = 3;    % Probability matching
       models(:,13) = 2;    % Lapse
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials

   case {31} % Bisensory standard models with deterministic decision making and lapse
       
       [options,models,groupcnd] = VestBMS(options,2,0);
       options.jobname = 'vest_dbim';
       models(:,11) = 1;    % BDT
       models(:,13) = 2;    % Lapse
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials
       
   case {41} % Bisensory standard models with deterministic decision making and lapse and simple causal inference (not necessary)
       
       [options,models,groupcnd] = VestBMS(options,2,0);
       options.jobname = 'vest_dsbim';
       models(:,11) = 1;    % BDT
       models(:,13) = 2;    % Lapse
       models(models(:,15) == 2,15) = 1;     % Standard Bayesian
       models(models(:,15) == 4,15) = 3;     % Fixed criterion       
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials
       
    case 101 % Bimodal standard models with constant noise
        
       [options,models,groupcnd] = VestBMS(options,2,0);
       models(:,[1 2]) = 1; % Constant noise
       options.jobname = 'vest_bim_const';
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials

    case 111 % Bimodal standard models with constant noise without beta
        
       [options,models,groupcnd] = VestBMS(options,2,0);
       models(:,[1 2]) = 1; % Constant noise
       options.jobname = 'vest_2bim_const';
       models(:,11) = 3;    % Probability matching
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials

   case 121 % Bisensory standard models with constant noise without beta and with lapse
       
       [options,models,groupcnd] = VestBMS(options,2,0);
       models(:,[1 2]) = 1; % Constant noise
       options.jobname = 'vest_lbim_const';
       models(:,11) = 3;    % Probability matching
       models(:,13) = 2;    % Lapse
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials

   case 131 % Bisensory standard models with constant noise, deterministic decision making and lapse
       
       [options,models,groupcnd] = VestBMS(options,2,0);
       models(:,[1 2]) = 1; % Constant noise
       options.jobname = 'vest_lbim_const';
       models(:,11) = 1;    % BDT
       models(:,13) = 2;    % Lapse
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials

   case {141} % Bisensory standard models with constant noise, deterministic decision making and lapse and simple causal inference
       
       [options,models,groupcnd] = VestBMS(options,2,0);
       models(:,[1 2]) = 1; % Constant noise
       options.jobname = 'vest_dsbim_const';
       models(:,11) = 1;    % BDT
       models(:,13) = 2;    % Lapse
       models(models(:,15) == 2,15) = 1;     % Standard Bayesian
       models(models(:,15) == 4,15) = 3;     % Fixed criterion       
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials
       
    % LARGE-DISPARITY TRIALS ONLY   
       
    case 201 % Bisensory models

       [options,models,groupcnd] = VestBMS(options,2,0);
       options.jobname = 'vest_bim_largedisparity';
       dataids(:,2) = setflag(dataids(:,2), [4,5]);     % No categorical trials, no small disparity
        
    case 211 % Bisensory models with constant noise
        
       [options,models,groupcnd] = VestBMS(options,2,0);
       models(:,[1 2]) = 1; % Constant noise
       options.jobname = 'vest_bim_const_largedisparity';
       dataids(:,2) = setflag(dataids(:,2), [4,5]);     % No categorical trials, no small disparity
       
%--------------------------------------------------------------------------        
% BISENSORY UNITY JUDGEMENT DATA FITS
       
   case 1001 % Bisensory standard models
        
       [options,models,groupcnd] = VestBMS(options,2,0);
       options.jobname = 'vest_unity';
       models(:,11) = 3;    % Probability matching
       models(models(:,15) == 5,:) = [];    % Remove forced fusion
       dataids = [(1:11)', zeros(11,1)];       
       dataids(:,2) = setflag(dataids(:,2), 3);     % No estimation trials

   case 1021 % Bisensory standard models with sinusoidal/constant noise with lapse
        
       [options,models,groupcnd] = VestBMS(options,2,0);
       models_const = models;
       models_const(:,[1 2]) = 1; % Constant noise
       models = [models; models_const];
       options.jobname = 'vest_lunity';
       models(:,11) = 3;    % Probability matching
       models(:,13) = 2;    % Lapse
       models(models(:,15) == 5,:) = [];    % Remove forced fusion
       dataids = [(1:11)', zeros(11,1)];       
       dataids(:,2) = setflag(dataids(:,2), 3);     % No estimation trials
       
   case 1031 % Bisensory standard models with random unity judgement
        
       [options,~,groupcnd] = VestBMS(options,2,0);
       options.jobname = 'vest_randunity';
       models = [10 10 1 1, 1 1 1 3, 1 1 1 1, 1 1 5 4 0];
       dataids = [(1:11)', zeros(11,1)];       
       dataids(:,2) = setflag(dataids(:,2), 3);     % No estimation trials

   case 1041 % Bisensory standard models with sinusoidal/constant noise, BDT and lapse (THIS MIGHT BE WRONG, IT DOES PROBABILITY MATCHING)
        
       [options,models,groupcnd] = VestBMS(options,2,0);
       models_const = models;
       models_const(:,[1 2]) = 1; % Constant noise
       models = [models; models_const];
       options.jobname = 'vest_dunity';
       models(:,11) = 1;    % BDT
       models(:,13) = 2;    % Lapse
       models(models(:,15) == 5,:) = [];    % Remove forced fusion
       models(:,15) = models(:,15) - 1;     % Remove softness
       dataids = [(1:11)', zeros(11,1)];       
       dataids(:,2) = setflag(dataids(:,2), 3);     % No estimation trials

   case 1051 % Bisensory standard models with sinusoidal/constant noise, probability matching and lapse
        
       [options,models,groupcnd] = VestBMS(options,2,0);
       models_const = models;
       models_const(:,[1 2]) = 1; % Constant noise
       models = [models; models_const];
       options.jobname = 'vest_dunity';
       models(:,11) = 3;    % Probability matching
       models(:,13) = 2;    % Lapse
       models(models(:,15) == 5,:) = [];    % Remove forced fusion
       models(:,15) = models(:,15) - 1;     % Remove softness
       dataids = [(1:11)', zeros(11,1)];       
       dataids(:,2) = setflag(dataids(:,2), 3);     % No estimation trials

   case 1061 % Bisensory standard models with sinusoidal/constant noise, real BDT and lapse
        
       [options,models,groupcnd] = VestBMS(options,2,0);
       models_const = models;
       models_const(:,[1 2]) = 1; % Constant noise
       models = [models; models_const];
       options.jobname = 'vest_rdunity';
       models(:,11) = 1;    % BDT
       models(:,13) = 2;    % Lapse
       models(models(:,15) == 5,:) = [];    % Remove forced fusion
       models(:,15) = models(:,15) - 1;     % Remove softness
       dataids = [(1:11)', zeros(11,1)];       
       dataids(:,2) = setflag(dataids(:,2), 3);     % No estimation trials
       
    case 1101 % Bimodal standard models with constant noise
        
       [options,models,groupcnd] = VestBMS(options,2,0);
       models(:,[1 2]) = 1; % Constant noise
       models(:,11) = 3;    % Probability matching
       models(models(:,15) == 5,:) = [];    % Remove forced fusion
       options.jobname = 'vest_unity_const';
       dataids = [(1:11)', zeros(11,1)];       
       dataids(:,2) = setflag(dataids(:,2), 3);     % No estimation trials
       
       
%--------------------------------------------------------------------------        
% FULL JOINT DATA FITS

   case 2001 % Full joint standard models (humans)
        
       options = VestBMS(options,2,0);
       groupcnd = 1:7;
       options.jobname = 'vest_joint_human';       
       models = [ ...
           5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 2 2 0; ... % Generalized Bayesian
           5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 4 2 0; ... % Soft fixed criterion
       ];       
       % models(:,11) = 3;    % Probability matching (might require change)
       dataids = [(1:11)', zeros(11,1)];       

   case 2002 % Full joint standard models (monkeys)
        
       options = VestBMS(options,2,0);
       groupcnd = 1:7;
       options.jobname = 'vest_joint_monkey';
       models = [ ...
           5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 2 2 0; ... % Generalized Bayesian
           5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 4 2 0; ... % Soft fixed criterion
       ];       
       % models(:,11) = 3;    % Probability matching (might require change)
       dataids = [12 8; 13 8; 14 8];
       dataids(:,2) = setflag(dataids(:,2), 4);     % No categorical trials

   case 2011 % Full joint standard models, separate criteria and softmax (humans)
        
       options = VestBMS(options,2,0);
       groupcnd = 1:7;
       options.jobname = 'vest_joint2_human';       
       models = [ ...
           5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 2 3 0; ... % Generalized Bayesian
           5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 4 3 0; ... % Soft fixed criterion
       ];       
       dataids = [(1:11)', zeros(11,1)];       
       
   case 2021 % Full joint standard models with lapse (humans)
        
       options = VestBMS(options,2,0);
       groupcnd = 1:7;
       options.jobname = 'vest_joint_human';       
       models = [ ...
           5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 2 2 0; ... % Generalized Bayesian
           5 3 1 1, 1 1 1 1, 1 1 2 1, 1 1 4 2 0; ... % Soft fixed criterion
       ];       
       models(:,11) = 3;    % Probability matching
       models(:,13) = 2;    % Lapse
       dataids = [(1:11)', zeros(11,1)];       
       
%--------------------------------------------------------------------------
% UNIMODAL ESTIMATION DATA FITS
% All models have by default: no rescaling, no motor noise, a fixed prior
% (it is irrelevant), no lapse, and softmax decision making.
                
    case {10001}; % Standard unimodal with sinusoidal noise
        
        [options,models,groupcnd] = VestBMS(options,1);
        options.jobname = 'vest_uni';

    case {10101}; % Standard unimodal with constant noise
        
        [options,models,groupcnd] = VestBMS(options,1);
        models(:,[1 2]) = 1; % Constant noise
        options.jobname = 'vest_uni_const';
        
    case 10201 % Standard unimodal with sinusoidal/constant noise and lapse
        
        [options,models,groupcnd] = VestBMS(options,1);
        models_const = models;
        models_const(:,[1 2]) = 1; % Constant noise
        models = [models; models_const];
        models(:,11) = 1;           % BDT (no softmax)
        models(:,13) = 2;           % Lapse        
        options.jobname = 'vest_lapse_uni';        

    case 10301 % Standard unimodal with sinusoidal/constant noise and lapse and fixed prior
        
        [options,models,groupcnd] = VestBMS(options,1);
        models_const = models;
        models_const(:,[1 2]) = 1; % Constant noise
        models = [models; models_const];
        models(:,8) = 3;            % Fixed prior
        models(:,11) = 1;           % BDT (no softmax)
        models(:,13) = 2;           % Lapse        
        options.jobname = 'vest_noprior_lapse_uni';        
        
end

% Set speed test values
%if any(groupcnd >= 5)
%    options = setoptions(options,'speedtest',10,1);  % Bimodal data
%else
%    options = setoptions(options,'speedtest',0.15,1);  % Unimodal data
%end

% Be verbose
options = setoptions(options,'display','all',1);

% Set conditions
for i = 1:nDatasets; cnd{i} = {groupcnd}; end

% Optimization run
if type > 0 && options.nsamples == 0
    options = setoptions(options,'optfevals',NITER_OPTIMIZATION,1);
    options = setoptions(options,'nsamples',0,1);
    options = setoptions(options,'samplingtemperature',1,1);
    options = setoptions(options,'hessianflag',0,1); % Too expensive - do not compute Hessian
end

return;

    %VESTBMS Define options for Kalpana's experiment
    function [options,models,groupcnd] = VestBMS(options,nStimuli,typeoffset)
        if nargin < 3; typeoffset = []; end
        
        options = setoptions(options,'experimentName','kalpana');
        options = setoptions(options,'bincenters',[-45,-40,-35,-30:2.5:-2.5,-1.25:0.625:1.25,2.5:2.5:30,35,40,45]);
        options = setoptions(options,'respbincenters',[-1,1]);
        options = setoptions(options,'nsamples',NSAMPLES(nStimuli),1);
                
        % Compute bin weights for beliefs about eccentricity-independent likelihoods (unused)
        w = +(abs(options.bincenters) <= 25 & options.bincenters ~= 0);
        w(abs(options.bincenters) < 2.5 & options.bincenters ~= 0) = 0.5;
        for icnd = 1:4
            binweights(:,icnd) = w/sum(w);
        end
        s = -25:5:25; % Mean heading direction
        d = [-40,-20,-10,-5,0,5,10,20,40]'; % Disparity
        s_all = bsxfun(@plus, s, d/2);
        w = zeros(length(options.bincenters),1);
        for iW = 1:length(options.bincenters)
            w(iW) = sum(s_all(:) == options.bincenters(iW));
        end
        for icnd = 5:7
            binweights(:,icnd) = w/sum(w);            
        end
        options = setoptions(options,'binweights',binweights);
        
        % Compute bimodal bin centers
        bincenters_bim{1} = zeros(length(s),length(d));
        bincenters_bim{2} = zeros(length(s),length(d));
        for i1 = 1:length(s)
            for i2 = 1:length(d)
                bincenters_bim{1}(i1,i2) = s(i1) + 0.5*d(i2);
                bincenters_bim{2}(i1,i2) = s(i1) - 0.5*d(i2);
            end
        end
        bincenters_bim{1} = bincenters_bim{1}(:);
        bincenters_bim{2} = bincenters_bim{2}(:);
        bincenters_bim{3} = options.respbincenters;
        options = setoptions(options,'bincenters_bim',bincenters_bim);
        
        if nStimuli == 1 % Unimodal data
            models = standardunimodalmodels;
            groupcnd = 1:4; % All unimodal conditions
            
        else % Bimodal data
            models = standardbimodalmodels;
            modid = type-typeoffset;
            groupcnd = 5:7;
            options = setoptions(options,'unifullthetanumber',modid);
        end
    end
end

%SWITCH2SINUSOIDALMODELS switch to sinusoidal noise models
function models = switch2sinusoidalnoise(models)
    ff = any(bsxfun(@eq,models(:,1),[2 4 6 8]),2);
    models(ff,1) = models(ff,1) + 1; 
    ff = any(bsxfun(@eq,models(:,2),[2 4 6 8]),2);
    models(ff,2) = models(ff,2) + 1; 
end