function string = VestBMS_getModelName(model)
% VESTBMS_GETMODELNAME return the model string.

% Bimodal-data models
switch model(15)
    case 1; string = 'BP';
    case 2; string = 'GBP';
    case 3; string = 'CX';
    case 4; string = 'SCX';
    case 5; string = 'FF';
end
        
        

end