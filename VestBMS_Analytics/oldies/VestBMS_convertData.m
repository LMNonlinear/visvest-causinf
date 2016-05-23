%VESTBMS_CONVERTDATA Convert Kalpana's data in a CueBMS-compatible format.

% Description of data matrix
% X(:, 1) Absolute trial number
% X(:, 2) Empty
% X(:, 3) Visual noise level (1 Low, 2 Med, 3 High)
% X(:, 4) Trial response type (1 Visual, 2 Vestibular, 3 Categorical)
% X(:, 5) Vestibular stimulus position
% X(:, 6) Visual stimulus position
% X(:, 7) Number of stimuli (1 Unimodal, 2 Bimodal)
% X(:, 8) Vestibular response
% X(:, 9) Visual response
% X(:, 10) Categorical response

function [data,bigdata] = VestBMS_convertData()

% All subjects:
% 9 and 14 have only 2 levels of visual reliability (instead of 3)
% 5 and 14 only have no bimodal localization trials
% 7 and 15 are missing

subjs = [1:4 6 8 10:13 16];
% bincenters = -45:2.5:45;
bincenters = [-45,-40,-35,-30:2.5:-2.5,-1.25:0.625:1.25,2.5:2.5:30,35,40,45];

for iSubj = 1:length(subjs)
    nid = subjs(iSubj)
    
    % Load unimodal data
    temp = load([num2str(nid) '_leftright.mat']);
    dataset = temp.dataset;
    D = dataset(dataset(:,1) == 1 | dataset(:,1) == 2, :);
    
    % Load bimodal data
    temp = load([num2str(nid) '_cause_leftright.mat']);
    dataset = temp.dataset;    
    D = [D; dataset(dataset(:,1) == 3 | dataset(:,1) == 4, :)];
    
    % Create empty datas matrix
    nTrials = size(D,1);
    X{iSubj} = zeros(nTrials, 10);    
    X{iSubj}(:, 1) = 1:nTrials;             % Trial number
    X{iSubj}(:, 3) = D(:, 7);               % Visual noise level
    
    temp = zeros(nTrials,1);
    temp(D(:, 1) == 1) = 2;                 % Vestibular-only trials
    temp(D(:, 1) == 2) = 1;                 % Visual-only trials
    temp(D(:, 1) == 3) = 3;                 % Categorization trials
    temp(D(:, 1) == 4) = 2;                 % Vestibular bimodal trials
    X{iSubj}(:, 4) = temp;                  % Trial response type
    
    X{iSubj}(:, 5) = D(:, 2);               % Vestibular stimulus position
    X{iSubj}(:, 6) = D(:, 3);               % Visual stimulus position
    X{iSubj}(:, 7) = 1 + (D(:, 1) >= 3);    % Number of stimuli
    
    D(D(:, 5) == 1, 5) = -1;                % Leftward response
    D(D(:, 5) == 2, 5) = 1;                 % Rightward response
    
    X{iSubj}(:,[8 9]) = NaN;
    f = X{iSubj}(:, 4) == 2;                % Vestibular trials
    X{iSubj}(f,8) = D(f,5);                 % Vestibular localization response
    f = X{iSubj}(:, 4) == 1;                % Visual trials
    X{iSubj}(f,9) = D(f,5);                 % Visual localization response
    
    X{iSubj}(:, 10) = D(:, 9);              % Categorical response
    
end

data = CueBMS_analytics(X,[],1,[],bincenters);
for i = 1:length(data); data{i}.id = i; end
display([num2str(length(data)), ' datasets successfully converted.']);

% All users data
allX = [];
for i = 1:length(data); allX = [allX; X{i}]; end

bigdata = CueBMS_analytics({allX},[],1,[],bincenters);
display('Mean subject dataset converted.');


end