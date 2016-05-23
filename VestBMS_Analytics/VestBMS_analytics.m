% Description of data matrix
% X(:, 1) Absolute trial number
% X(:, 2) Empty
% X(:, 3) Visual noise level (1 Low, 2 Med, 3 High)
% X(:, 4) Trial response type (1 Visual, 2 Audio, 3 Categorical)
% X(:, 5) Audio stimulus position
% X(:, 6) Visual stimulus position
% X(:, 7) Number of stimuli (1 Unimodal, 2 Bimodal)
% X(:, 8) Audio response
% X(:, 9) Visual response
% X(:, 10) Categorical response

function [data bigdata] = VestBMS_analytics(datasets,discardoutliers,robustfitflag,quickplotflag,bincenters)

if ~exist('discardoutliers', 'var') || isempty(discardoutliers); discardoutliers = 1; end
if ~exist('robustfitflag', 'var') || isempty(robustfitflag); robustfitflag = 0; end
if ~exist('quickplotflag', 'var') || isempty(quickplotflag); quickplotflag = 1; end
if ~exist('bincenters', 'var') || isempty(bincenters); bincenters = -15:5:15; end

data = [];
bigdata = [];
    
if ischar(datasets{1})
    loadfiles = 1;
elseif ismatrix(datasets{1})
    loadfiles = 0;
else
    error('A list of file names or existing datasets need to be provided.');
end

% Screen mean (in pixels)
SCREENMU = 507;

% Conversion constant from pixels to degrees
PIX2DEG = 0.0892857142;

% Remove outliers outside of this number of standard deviations away
TRIMOUTLIERSD = 3;

% Constants
UNIAUDIO = 4;
BIMVIDEO = 1;
BIMAUDIO = 2;
BIMCATEGORY = 3;
noiseString = {'low noise', 'medium noise', 'high noise'};
typestring = {'video', 'audio', 'categorical'};
bimodalTypeColumn = [4 3];

for ii = 1:length(datasets)
    
    % Either load dataset from file or use provided one
    if loadfiles
        datasets{ii}
        load([datasets{ii} '.mat']);
        % Save subject's ID
        D.id = ii;
        D.name = datasets{ii};
        convert = 1;
    else
        userdata = datasets{ii};
        convert = 0;
    end
    
    % Assign trial number if not already present
    if all(userdata(:,1) == 0)
        userdata(:, 1) = 1:size(userdata, 1);
    end
    
    mask = 1:size(userdata, 1);    
    X = userdata(mask, :);
    if convert
        % Visual noise levels    
        X(X(:,3)==21, 3) = 1;
        X(X(:,3)==130, 3) = 2;
        X(X(:,3)==250, 3) = 3;
        X(:,[5 6 8 9]) = (X(:,[5 6 8 9]) - SCREENMU)*PIX2DEG;
        X(:,5) = round(X(:,5)); % Auditory stimulus is rounded to degrees
    end
    
    D.VisualNoiseLevel = X(:, 3);    
    % Remove absent response from unimodal trials
    X(X(:,4)==1 & X(:,7)==1, 5) = NaN;
    X(X(:,4)==2 & X(:,7)==1, 6) = NaN;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Discard trials
    
    % Remove trials with response 40 deg away from the mean
    f = (abs(X(:, 8)) > 40 & X(:, 4) == 2) | (abs(X(:, 9)) > 40 & X(:, 4) == 1);   

    % Remove trials with visual stimulus outside a certain range, unless
    % they are standard fare    
    if sum(sum(abs(X(:,[5 6]) > 20))) > 20; kalpanasdataset = 1; else kalpanasdataset = 0; end
    if ~kalpanasdataset; f = f | (abs(X(:, 6)) > 20); end
        
    X(f, :) = [];    
    
    D.X.all = X;
    D.botched = sum(f);
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Divide dataset by condition
    
    % Unimodal trials
    for iNoise = 1:3 % Visual
        D.X.unimodal{iNoise} = X(X(:,4)==1 & X(:, 3)==iNoise & X(:,7)==1, [1 6 9]);
    end
    D.X.unimodal{UNIAUDIO} = X(X(:,4)==2 & X(:,7)==1, [1 5 8]); % Audio
    
    % Bimodal trials
    for iNoise = 1:3
        D.X.bimodal{iNoise}{BIMVIDEO} = X(X(:,4)==1 & X(:, 3)==iNoise & X(:,7)==2, [1 4 5 6 9]); % Video response
        D.X.bimodal{iNoise}{BIMAUDIO} = X(X(:,4)==2 & X(:, 3)==iNoise & X(:,7)==2, [1 4 5 6 8]); % Audio response
        D.X.bimodal{iNoise}{BIMCATEGORY} = X(X(:,4)==3 & X(:, 3)==iNoise & X(:,7)==2, [1 4 5 6 10]); % Categorical response
        % Divide data only by noise level
        D.X.bimodalall{iNoise} = [D.X.bimodal{iNoise}{BIMVIDEO}; D.X.bimodal{iNoise}{BIMAUDIO}; D.X.bimodal{iNoise}{BIMCATEGORY}];
        % Disparity (visual position minus audio position)
        D.X.bimdisp{iNoise}{BIMVIDEO} = [D.X.bimodal{iNoise}{BIMVIDEO}(:, [1 2]), bsxfun(@minus, D.X.bimodal{iNoise}{BIMVIDEO}(:, [4 5]), D.X.bimodal{iNoise}{BIMVIDEO}(:, 3))];
        D.X.bimdisp{iNoise}{BIMAUDIO} = [D.X.bimodal{iNoise}{BIMAUDIO}(:, [1 2]), bsxfun(@minus, D.X.bimodal{iNoise}{BIMAUDIO}(:, [4 5]), D.X.bimodal{iNoise}{BIMAUDIO}(:, 3))];
        D.X.bimdisp{iNoise}{BIMCATEGORY} = [D.X.bimodal{iNoise}{BIMCATEGORY}(:, [1 2]), D.X.bimodal{iNoise}{BIMCATEGORY}(:, 4) - D.X.bimodal{iNoise}{BIMCATEGORY}(:, 3), D.X.bimodal{iNoise}{BIMCATEGORY}(:, 5)];
    end    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Cross-validation datasets?
    
    % ...
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Bin data, mostly for visualization purposes
    audbincenters = bincenters;    
    % vidbincenters = -18:3:18;
    vidbincenters = bincenters;
    vidbinradius = diff(vidbincenters(1:2))/2;
    dispbincenters = -20:5:20;
    dispbinradius = diff(dispbincenters(1:2))/2;

    % Unimodal bins
    for iNoise = 1:3
        D.binX.unimodal{iNoise} = binbuild(D.X.unimodal{iNoise}(:, 2), D.X.unimodal{iNoise}(:, end), vidbincenters, [], TRIMOUTLIERSD);
        D.binX.unimodal{iNoise}.type = ['Unimodal video response trials, ' noiseString{iNoise}];
    end
    D.binX.unimodal{UNIAUDIO} = binbuild(D.X.unimodal{UNIAUDIO}(:, 2), D.X.unimodal{UNIAUDIO}(:, end), audbincenters, [], TRIMOUTLIERSD, robustfitflag);
    D.binX.unimodal{UNIAUDIO}.type = ['Unimodal audio response trials, ' noiseString{iNoise}];
        
    % Bimodal bins
    % Audiovisual trials
    for iNoise = 1:3
        for iType = [BIMVIDEO BIMAUDIO];
            % Standard bins
            D.binX.bimodal{iNoise}{iType}.x1 = audbincenters;
            D.binX.bimodal{iNoise}{iType}.x2 = vidbincenters;
            D.binX.bimodal{iNoise}{iType}.ymeans = zeros(size(audbincenters, 2), size(vidbincenters, 2));
            D.binX.bimodal{iNoise}{iType}.ystd = zeros(size(audbincenters, 2), size(vidbincenters, 2));
            D.binX.bimodal{iNoise}{iType}.n = zeros(size(audbincenters, 2), size(vidbincenters, 2));
            D.binX.bimodal{iNoise}{iType}.discarded = zeros(size(audbincenters, 2), size(vidbincenters, 2));
            for iBin = 1:size(audbincenters, 2)
                for jBin = 1:size(vidbincenters, 2)
                    Y = D.X.bimodal{iNoise}{iType}(D.X.bimodal{iNoise}{iType}(:, 3) == audbincenters(iBin) & ...
                        abs(D.X.bimodal{iNoise}{iType}(:, 4) - vidbincenters(jBin)) <= vidbinradius, end);
                    D.binX.bimodal{iNoise}{iType}.y{iBin, jBin} = Y;
                    D.binX.bimodal{iNoise}{iType}.ymeans(iBin, jBin) = nanmean(Y);
                    D.binX.bimodal{iNoise}{iType}.ystd(iBin, jBin) = nanstd(Y);
                    D.binX.bimodal{iNoise}{iType}.n(iBin, jBin) = length(Y);
                end
            end
            
            % Disparity bins
            D.binX.bimdisp{iNoise}{iType}.x = dispbincenters;
            D.binX.bimdisp{iNoise}{iType}.ymeans = zeros(1, size(dispbincenters, 2));
            D.binX.bimdisp{iNoise}{iType}.ystd = zeros(1, size(dispbincenters, 2));
            D.binX.bimdisp{iNoise}{iType}.n = zeros(1, size(dispbincenters, 2));
            D.binX.bimdisp{iNoise}{iType}.discarded = zeros(1, size(dispbincenters, 2));
            for iBin = 1:size(dispbincenters, 2)
                Y = D.X.bimdisp{iNoise}{iType}(abs(D.X.bimdisp{iNoise}{iType}(:, 3) - dispbincenters(iBin)) <= dispbinradius, end);
                D.binX.bimdisp{iNoise}{iType}.y{iBin} = Y;
                D.binX.bimdisp{iNoise}{iType}.ymeans(iBin) = nanmean(Y);
                D.binX.bimdisp{iNoise}{iType}.ystd(iBin) = nanstd(Y);
                D.binX.bimdisp{iNoise}{iType}.n(iBin) = length(Y);
            end
        end
    end
    
    % Categorical trials
    for iNoise = 1:3
        % Standard bins
        D.binX.bimodal{iNoise}{BIMCATEGORY}.x1 = audbincenters;
        D.binX.bimodal{iNoise}{BIMCATEGORY}.x2 = vidbincenters;
        %D.binX.bimodal{iNoise}{iType}.ymeans = zeros(size(audbincenters, 2), size(vidbincenters, 2));
        %D.binX.bimodal{iNoise}{iType}.ystd = zeros(size(audbincenters, 2), size(vidbincenters, 2));
        %D.binX.bimodal{iNoise}{iType}.n = zeros(size(audbincenters, 2), size(vidbincenters, 2));
        %D.binX.bimodal{iNoise}{iType}.discarded = zeros(size(audbincenters, 2), size(vidbincenters, 2));
        for iBin = 1:size(audbincenters, 2)
            f = D.X.bimodal{iNoise}{BIMCATEGORY}(:, 3) == audbincenters(iBin);
            Y = D.X.bimodal{iNoise}{BIMCATEGORY}(f, [4 end]);
            D.binX.bimodal{iNoise}{BIMCATEGORY}.y{iBin} = Y;
            %D.binX.bimodal{iNoise}{iType}.ymeans(iBin, jBin) = nanmean(Y);
            %D.binX.bimodal{iNoise}{iType}.ystd(iBin, jBin) = nanstd(Y);
            %D.binX.bimodal{iNoise}{iType}.n(iBin, jBin) = length(Y);
        end
        
        % Last bin contains spatial disparity
        if isempty(D.X.bimdisp{iNoise}{BIMCATEGORY})
            D.binX.bimodal{iNoise}{BIMCATEGORY}.y{end+1} = [];            
        else
            D.binX.bimodal{iNoise}{BIMCATEGORY}.y{end+1} = D.X.bimdisp{iNoise}{BIMCATEGORY}(:, [3 4]);
        end
    end
    
            
    if ~quickplotflag
        D.binX.discarded = [];
        for i = 1:4; D.binX.discarded = sum(D.binX.unimodal{i}.discarded); end
        for iNoise = 1:3
            D.binX.discarded = D.binX.discarded + sum(D.binX.bimodal{iNoise}{BIMVIDEO}.discarded(:)); 
            D.binX.discarded = D.binX.discarded + sum(D.binX.bimodal{iNoise}{BIMAUDIO}.discarded(:)); 
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compute performance per session and condition
    
    D.performance = NaN(5, 5);
    trialsPerSession = 600;
    for iSession = 1:5
        trials = (1:trialsPerSession) + (iSession-1)*trialsPerSession;
        
        % Unimodal visual data
        sqerr = 0; n = 0;
        for iNoise = 1:3
            x = D.X.unimodal{iNoise};
            f = any(bsxfun(@eq, x(:,1), trials),2);
            n = n + nansum(f);
            sqerr = sqerr + nansum((x(f, 2) - x(f, 3)).^2);
        end
        D.performance(iSession,1) = sqrt(sqerr/n);
        
        % Unimodal audio data
        x = D.X.unimodal{4};
        f = any(bsxfun(@eq, x(:,1), trials),2);
        D.performance(iSession,2) = sqrt(nansum((x(f, 2) - x(f, 3)).^2)/nansum(f));
        
        % Bimodal data (visual, audio and categorical)
        sqerr = zeros(1,3); n = zeros(1, 3);
        for iNoise = 1:3
            x = D.X.bimodalall{iNoise};
            f = any(bsxfun(@eq, x(:,1), trials),2) & x(:, 2) == BIMVIDEO;
            n(1) = n(1) + nansum(f);
            sqerr(1) = sqerr(1) + nansum((x(f, 4) - x(f, end)).^2);
            f = any(bsxfun(@eq, x(:,1), trials),2) & x(:, 2) == BIMAUDIO;
            n(2) = n(2) + nansum(f);
            sqerr(2) = sqerr(2) + nansum((x(f, 3) - x(f, end)).^2);
            f = any(bsxfun(@eq, x(:,1), trials),2) & x(:, 2) == BIMCATEGORY;
            n(3) = n(3) + nansum(f);
            y = abs(x(:, 3) - x(:, 4)) < 1e-6;  % Unity trials
            r = 2 - x(:, end);
            sqerr(3) = sqerr(3) + nansum((y(f) - r(f)).^2);
        end
        D.performance(iSession,3:5) = sqrt(sqerr./n);
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % No binning here, we use kernel regression estimate for visualization
    if 0    
        h = 2.5; % Kernel width of 2.5 degrees
        for iNoise = 1:3
            if ~isempty(D.X.unimodal{iNoise})
        %        D.kreX.unimodal{iNoise}.mean = ksr(D.X.unimodal{iNoise}(:, 2), D.X.unimodal{iNoise}(:, end) - D.X.unimodal{iNoise}(:, 2), [], 101, [-20, 20]);
                D.kreX.unimodal{iNoise}.mean = ksr(D.X.unimodal{iNoise}(:, 2), D.X.unimodal{iNoise}(:, end), h, 101, [-20, 20], TRIMOUTLIERSD, robustfitflag);
                D.kreX.unimodal{iNoise}.type = ['Unimodal video response trials, ' noiseString{iNoise}];
            end
        end
        %D.binX.unimodal{UNIAUDIO} = binbuild(D.X.unimodal{UNIAUDIO}(:, 2), D.X.unimodal{UNIAUDIO}(:, end), audbincenters, [], TRIMOUTLIERSD, robuststats);
        %D.binX.unimodal{UNIAUDIO}.type = ['Unimodal audio response trials, ' noiseString{iNoise}];

        % Same for bimodal data
        for iNoise = 1:3  
            if ~isempty(D.X.bimodal{iNoise})
                for iBin = 1:length(audbincenters)
                    if size(D.X.bimodal{iNoise}{BIMVIDEO}, 1) > 0
                        dd = D.X.bimodal{iNoise}{BIMVIDEO}(D.X.bimodal{iNoise}{BIMVIDEO}(:, 3) == audbincenters(iBin), :);                
                        if ~isempty(dd); D.kreX.bimodal{iNoise}{iBin}.mean_vis = ksr(dd(:, 4), dd(:, 5), h, 101, [-20, 20], TRIMOUTLIERSD, robustfitflag); end
                    end
                    if size(D.X.bimodal{iNoise}{BIMAUDIO}, 1) > 0
                        dd = D.X.bimodal{iNoise}{BIMAUDIO}(D.X.bimodal{iNoise}{BIMAUDIO}(:, 3) == audbincenters(iBin), :);                
                        if ~isempty(dd); D.kreX.bimodal{iNoise}{iBin}.mean_aud = ksr(dd(:, 4), dd(:, 5), h, 101, [-20, 20], TRIMOUTLIERSD, robustfitflag); end
                    end
                    % D.kreX.bimodal{iNoise}.type = ['Bimodal video response trials, ' noiseString{iNoise}];
                end
            end
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Linear fit to unimodal data
    
    if ~quickplotflag
        for iNoise = 1:4        
            x = D.X.unimodal{iNoise}(:, 2);
            y = D.X.unimodal{iNoise}(:, 3);
            if ~isempty(x) && ~isempty(y)
                [a b] = linearfit(x, y, robustfitflag);
                D.linearfit.unimodal{iNoise}.a = a;
                D.linearfit.unimodal{iNoise}.stats = b;
            else
                D.linearfit.unimodal{iNoise}.a = [];
                D.linearfit.unimodal{iNoise}.stats = [];                
            end
        end
    end
    
    data{ii} = D;
    clear D;
    
end

end


% Compute linear fit either with a robust fit or not
function [lfit, stats] = linearfit(x, y, robustfitflag)

    nans = isnan(x) | isnan(y);
    x(nans) = []; y(nans) = [];
    if robustfitflag
        [lfit, stats] = robustfit(x, y, 'ols');
    else
        pfit = polyfit(x, y, 1);
        lfit = circshift(pfit, [1 1]);
        stats = [];            
    end

end