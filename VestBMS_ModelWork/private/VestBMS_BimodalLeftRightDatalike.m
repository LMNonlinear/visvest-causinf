% CUEBMS_BIMODALDATALIKE Calculate log likelihood of bimodal dataset X
% under model MODEL and parameter set THETA for binned responses.
%
% X is a unimodal data matrix. Each row is a trial. For a given row, the 
% columns contain data for:
% X(1) Number of trial (unused),
% X(2) Task type (1 Visual localisation, 2 Audio localisation, 3 Categorisation)
% X(3) Audio stimulus position (deg),
% X(4) Visual stimulus position (deg),
% X(5) Response (deg or category).
%
% MODEL is the model class parameter vector.
%
% THETA is the model-dependent parameter vector for the current condition. 
% The values of THETA are:
% THETA(1) sigmazero; THETA(2) szero; 
% THETA(3) alpha (scaling factor); THETA(4) beta (shift factor); 
% THETA(5) kappa (power-law); THETA(6) lambda (lapse rate).
%
% PRIORINFO is the model-depent parameter vector for the prior:
% PRIORINFO(1)  Gaussian mean
% PRIORINFO(2)  Gaussian SD
% PRIORINFO(3)  p_common
% PRIORINFO(4)  k_common
% 
% Example of external usage:
% d = data{1, 3}; model = [6 3 5 2 1]; theta = [0.03 -0.055, 0.06 0.14, 10 0 0.2];
% ParticleCatch_datalike(d.niceData, d.priormix, model, theta, d.priorsinglegauss)
%
function varargout = VestBMS_BimodalLeftRightDatalike(X,model,theta,priorinfo,bincenters,maxranges,XGRID,SSCALE,sumover,randomize)

% Program constants
if nargin < 7 || isempty(XGRID) || isnan(XGRID); XGRID = 201; end
if nargin < 8 || isempty(SSCALE); SSCALE = 8; end
if nargin < 9 || isempty(sumover); sumover = 1; end
if nargin < 10 || isempty(randomize); randomize = 0; end

% Use closed form expression for Gaussians (ignores screen bounds!)
closedformflag = 0;

% When integrating a Gaussian, go up to this SDs away
MAXSD = 5;

% Cutoff to the penalty for a single outlier
FIXEDLAPSEPDF = 1e-4;

% Take model parameters
sigmazero_vis = theta(1);
w_vis = theta(2);
sigmalikezero_vis = theta(3);
wlike_vis = theta(4);
alpha_rescaling_vis = 1;
% beta_rescaling_vis = 0;

sigmazero_vest = theta(7);
w_vest = theta(8);
sigmalikezero_vest = theta(9);
wlike_vest = theta(10);
alpha_rescaling_vest = 1;
% beta_rescaling_vest = 0;

beta_softmax = theta(14);
gamma_causinf = theta(15);
tau_causinf = theta(16);

% Model selection parameter
priorc1 = priorinfo(end-1);
kcommon = priorinfo(end);

MAXRNG = maxranges(1);

% Is the internal noise Gaussian?
if ( ( wlike_vis == 0 && wlike_vest == 0 ) ...
        || ((model(4) == 6 || model(4) == 8)  && model(5) == 6))
    gaussianflag = 1;
else
    gaussianflag = 0;
    if model(4) == 6 || model(5) == 6; error('Unsupported measurement-based likelihood.'); end
end

% Bin centers is a column vector
bincenters_vis = bincenters{1};
bincenters_vest = bincenters{2};

% Compute sensory noise std per trial for vision
if w_vis >= 0; noisemodel_vis = 'Q'; else noisemodel_vis = 'C'; end
sigmas_vis = VestBMS_sensoryNoise(noisemodel_vis,bincenters_vis,sigmazero_vis,w_vis);
if isscalar(sigmas_vis); sigmas_vis = sigmas_vis*ones(numel(bincenters_vis),1); end

% Compute sensory noise std per trial for vestibular
if w_vest >= 0; noisemodel_vest = 'Q'; else noisemodel_vest = 'C'; end
sigmas_vest = VestBMS_sensoryNoise(noisemodel_vest,bincenters_vest,sigmazero_vest,w_vest);
if isscalar(sigmas_vest); sigmas_vest = sigmas_vest*ones(numel(bincenters_vest),1); end

% Measurements
xrange_vis = zeros(1, XGRID, 1);
xrange_vest = zeros(1, 1, XGRID);
xrange_vis(1, :, 1) = alpha_rescaling_vis*linspace(max(min(bincenters_vis-MAXSD*sigmas_vis),-MAXRNG), min(max(bincenters_vis+MAXSD*sigmas_vis), MAXRNG), XGRID);
xrange_vest (1, 1, :) = alpha_rescaling_vest*linspace(max(min(bincenters_vest-MAXSD*sigmas_vest),-MAXRNG), min(max(bincenters_vest+MAXSD*sigmas_vest), MAXRNG), XGRID);
dx_vis = xrange_vis(1, 2, 1) - xrange_vis(1, 1, 1);
dx_vest = xrange_vest(1, 1, 2) - xrange_vest(1, 1, 1);

% Add random jitter to XRANGE's to estimate error in the computation of the 
% log likelihood due to the current grid size
if randomize
    xrange_vis = xrange_vis + dx_vis*(rand()-0.5);
    xrange_vest = xrange_vest + dx_vest*(rand()-0.5);
end

srange = linspace(-MAXRNG, MAXRNG, MAXRNG*SSCALE*2 + 1)';
ds = diff(srange(1:2));

if nargout > 1 % Save variables for debug or data generation
    extras.xrange_vis = xrange_vis;
    extras.xrange_vest = xrange_vest;
    extras.srange = srange;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute likelihood; variable range depends on type

if gaussianflag
    likerange_vis = xrange_vis; 
    likerange_vest = xrange_vest; 
else
    likerange_vis = srange; 
    likerange_vest = srange; 
end

% Compute sensory likelihood std for vision
if wlike_vis >= 0; likemodel_vis = 'Q'; else likemodel_vis = 'C'; end
sigmasprime_vis = VestBMS_sensoryNoise(likemodel_vis,likerange_vis,sigmalikezero_vis,wlike_vis);

% Compute sensory likelihood std for vestibular
if wlike_vest >= 0; likemodel_vest = 'Q'; else likemodel_vest = 'C'; end
sigmasprime_vest = VestBMS_sensoryNoise(likemodel_vest,likerange_vest,sigmalikezero_vest,wlike_vest);

if ~gaussianflag || ~closedformflag
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compute likelihood for non-Gaussian likelihoods

    like_vis = bsxfun_normpdf(xrange_vis,srange,sigmasprime_vis);
    like_vest = bsxfun_normpdf(xrange_vest,srange,sigmasprime_vest);
    
    % Compute prior, p(s)
    priorpdf = bsxfun_normpdf(srange,priorinfo(1),priorinfo(2));
    priorpdf = priorpdf/(qtrapz(priorpdf, 1)*ds); % Normalize prior

    % Compute unnormalized posterior and rightward posterior (C = 2)
    postpdf_c2 = bsxfun(@times, priorpdf, like_vest);
    if priorc1 < 1
        postright_c2(1,:,:) = VestBMS_PostRight(postpdf_c2);
    else
        postright_c2 = 0;
    end
        
    % Compute unnormalized posterior and rightward posterior (C = 1)
    if priorc1 > 0
        postpdf_c1 = bsxfun(@times, postpdf_c2, like_vis);
        postright_c1(1,:,:) = VestBMS_PostRight(postpdf_c1);
    else
        postpdf_c1 = 0;
        postright_c1 = 0;
    end
        
    if nargout > 1 
        extras.postright_c2 = postright_c2;    
        extras.postright_c1 = postright_c1; 
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compute causal inference weights

    % Compute marginal likelihood, p(x_vis, x_vest|C)

    if model(15) == 1 || model(15) == 2
        % CASE C=2, Independent likelihoods
        likec2_vis = bsxfun(@times, priorpdf, like_vis);
        likec2 = (bsxfun(@times, qtrapz(likec2_vis, 1)*ds, qtrapz(postpdf_c2, 1)*ds)) + realmin; 

        % CASE C=1, Likelihoods are not independent
        likec1 = qtrapz(postpdf_c1, 1)*ds + realmin;
        % postpdfc1 = bsxfun(@rdivide, postpdfc1, likec1);
    end

    % Compute weight for cue fusion
    switch model(15)
        case 1  % Model weight is Bayesian posterior p(C=1|x_1, x_2)
            % likec1 = squeeze(likec1);
            w1 = likec1*priorc1./(likec1*priorc1 + likec2*(1-priorc1));

        case 2  % Generalized Bayesian causal inference
            % likec1 = squeeze(likec1);
            postc1 = likec1*priorc1./(likec1*priorc1 + likec2*(1-priorc1));
            w1 = 1./(1 + exp(gamma_causinf*(1-2*postc1)));
            
        case 3 % Non-Bayesian, criterion on x
            w1 = abs(bsxfun(@minus, xrange_vis, xrange_vest)) < kcommon;

        case 4 % Soft criterion on x
            w1 = 1./(1 + exp(tau_causinf*(abs(bsxfun(@minus, xrange_vis, xrange_vest)) - kcommon)));
            
        case 5 % Forced fusion
            w1 = 1;
            
    end
    
    % NaNs can emerge as 0/0 - assume that the response becomes random
    w1(isnan(w1)) = 0.5;
    
    if nargout > 1 % Save variables for debug or data generation
        extras.w1 = w1;
        % extras.postpdfc1 = postpdfc1;
    end
    
    % Compute posterior probability of rightward motion    
    postright = bsxfun(@plus, bsxfun(@times, w1, postright_c1), bsxfun(@times, 1-w1, postright_c2));
    
    % Probability of rightward response
    prright = 1./(1 + ((1-postright)./postright).^beta_softmax); 

    % Clean up memory
    clear postright w1 postpdf_c1 postpdf_c2 postright_c1 postright_c2 ...
        likec1 likec2 likec2_vis postpdfc1 postc1;

else
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compute likelihood for Gaussian likelihoods

    error('Closed form computation not supported (yet).');
    
    SSCALE = 8;
    srange = linspace(-MAXRNG, MAXRNG, MAXRNG*SSCALE*2 + 1)';
    ds = diff(srange(1:2));

    if nargout > 1 % Save variables for debug or data generation
        extras.xrange_vis = xrange_vis;
        extras.xrange_vest = xrange_vest;
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compute optimal targets for vision and vestibular (C=2)

    theta_vis = [theta(1:6) theta(13:14)];
    sstaruni_vis = OptimalTargetUnimodalGaussian(X(X(:, 2)==1, 4), model, theta_vis, priorinfo, xrange_vis(:)')';
    theta_vest = [theta(7:12) theta(13:14)];
    sstaruni_vest = OptimalTargetUnimodalGaussian(X(X(:, 2)==2, 3), model, theta_vest, priorinfo, xrange_vest(:)');

    if nargout > 1 
        extras.sstaruni_vis = sstaruni_vis;    
        extras.sstaruni_vest = sstaruni_vest; 
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compute strength of cue fusion

    % Compute marginal likelihood, p(x_vis, x_vest|C)

    % CASE C=2, Independent likelihoods
    likec2_vis = priorinfo(3)*normpdf(xrange_vis, priorinfo(1), sqrt(priorinfo(2)^2 + sigmasprime2_vis)) + ...
        (1-priorinfo(3))*normpdf(xrange_vis, priorinfo(4), sqrt(priorinfo(5)^2 + sigmasprime2_vis));
    likec2_vest = priorinfo(3)*normpdf(xrange_vest, priorinfo(1), sqrt(priorinfo(2)^2 + sigmasprime2_vest)) + ...
        (1-priorinfo(3))*normpdf(xrange_vest, priorinfo(4), sqrt(priorinfo(5)^2 + sigmasprime2_vest));
    likec2 = squeeze(bsxfun(@times, likec2_vis, likec2_vest));

    % CASE C=1, Likelihoods are not independent
    sigma2sum = bsxfun(@plus, sigmasprime2_vis, sigmasprime2_vest);
    sigmatilde2 = bsxfun(@times, sigmasprime2_vis, sigmasprime2_vest)./sigma2sum;
    mutilde = bsxfun(@plus, bsxfun(@times, xrange_vis, sigmasprime2_vest), bsxfun(@times, xrange_vest, sigmasprime2_vis))./sigma2sum;
    z1 = priorinfo(3) * exp(-0.5*bsxfun(@minus, xrange_vis, xrange_vest).^2./sigma2sum)./sqrt(sigma2sum) .* ...
        exp(-0.5*(mutilde - priorinfo(1)).^2./(priorinfo(2)^2 + sigmatilde2))./sqrt(priorinfo(2)^2 + sigmatilde2) / (2*pi);
    z2 = (1-priorinfo(3)) * exp(-0.5*bsxfun(@minus, xrange_vis, xrange_vest).^2./sigma2sum)./sqrt(sigma2sum) .* ...
        exp(-0.5*(mutilde - priorinfo(4)).^2./(priorinfo(5)^2 + sigmatilde2))./sqrt(priorinfo(5)^2 + sigmatilde2) / (2*pi);            

    % Compute weight for cue fusion
    switch model(15)
        case 1 % Model weight is Bayesian posterior p(C=1|x_1, x_2)
            likec1 = squeeze(z1 + z2);
            postc1 = likec1.*priorc1./(likec1.*priorc1 + likec2.*(1-priorc1));
            if priorc1cat ~= priorc1
                postc1cat = likec1*priorc1cat./(likec1*priorc1cat + likec2*(1-priorc1cat));
            end
            if softmaxbeta > 0
                postc1beta = 1./(1+exp(softmaxbeta*(1-2*postc1)));
            end            
        case {2, 3} % Non-Bayesian, distance on x    
            if softmaxbeta > 0
                postc1 = 1./(1 + exp(softmaxbeta_multx*softmaxbeta*(abs(bsxfun(@minus, xrange_vis, xrange_vest)) - kcommon)));
            else
                postc1 = abs(bsxfun(@minus, xrange_vis, xrange_vest)) < kcommon;
            end
            postc1 = squeeze(postc1);
        case {4, 5} % Non-Bayesian, distance on shat
            postc1 = abs(bsxfun(@minus, sstaruni_vis, sstaruni_vest)) < kcommon;
        case 6 % Model weight is Bayesian posterior but extra stuff for unity
            likec1 = squeeze(z1 + z2);
            postc1 = likec1.*priorc1./(likec1.*priorc1 + likec2.*(1-priorc1));
            extrapostc1 = abs(bsxfun(@minus, sstaruni_vis, sstaruni_vest)) < kcommon;
            extrapostc1 = squeeze(extrapostc1);
    end
    if nargout > 1 % Save variables for debug or data generation
        extras.postc1 = postc1;
        if priorc1cat ~= priorc1
            extras.postc1cat = postc1cat;
        end    
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compute optimal target for bimodal (C=1)

    if isinf(beta_softmax)
        if sigmaloss == 0
            error('MAP decision rule not supported for bimodal data yet.');
            %[~, index] = max(postpdfc1, [], 1);
            %sstarbim(:, :) = srange(squeeze(index));        
        elseif isinf(sigmaloss)
            mustar1 = (mutilde*priorinfo(2)^2 + priorinfo(1)*sigmatilde2)./(sigmatilde2 + priorinfo(2)^2);
            mustar2 = (mutilde*priorinfo(5)^2 + priorinfo(4)*sigmatilde2)./(sigmatilde2 + priorinfo(5)^2);
            sstarbim = squeeze((mustar1.*z1 + mustar2.*z2)./(z1 + z2));        
        end

        if nargout > 1 % Save variables for debug or data generation
            extras.sstarbim = sstarbim;
            extras.postpdfc1 = [];            
        end
    end  
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute overall optimal targets

xpdf_vis = bsxfun_normpdf(xrange_vis, alpha_rescaling_vis*bincenters_vis,alpha_rescaling_vis*sigmas_vis);
xpdf_vis = bsxfun(@rdivide, xpdf_vis, qtrapz(xpdf_vis, 2));
xpdf_vest = bsxfun_normpdf(xrange_vest, alpha_rescaling_vest*bincenters_vest,alpha_rescaling_vest*sigmas_vest);
xpdf_vest = bsxfun(@rdivide, xpdf_vest, qtrapz(xpdf_vest, 3));

xpdf2 = bsxfun(@times, xpdf_vis, xpdf_vest); % These guys are already normalized (volume element aside)

prmat = zeros(numel(bincenters_vest), 2);

prmat(:,2) = qtrapz(qtrapz(bsxfun(@times, xpdf2, prright), 2), 3);
prmat(:,1) = 1 - prmat(:,2);

% Fix probabilities
prmat = min(max(prmat,0),1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Finalize log likelihood

prmat = FIXEDLAPSEPDF + (1-FIXEDLAPSEPDF)*prmat;
prmat = prmat(:);

if nargout > 1
    extras.responsepdf = prmat;
end

xx = [X{1}; X{2}];

if sumover
    loglike = sum(xx(:).*log(prmat));
    varargout{1} = loglike;
else
    varargout{1} = prmat.^xx(:);
end
if nargout > 1; varargout{2} = extras; end

end