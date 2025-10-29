function [chosen_object, chosen_location] = deduce_choice(trial_type, outcome)
% This function deduces the animal's choice (object and location) based on
% the TrialType and the Outcome (1=Correct, 0=Incorrect).

    % Define the mapping for all 6 trial types (Ground Truth)
    % Columns: [Correct_Object, Correct_Location, Incorrect_Object, Incorrect_Location]
    % Objects: 1='Flower', 2='Spider', 3='Airplane'
    % Locations: 1='Left', 2='Center', 3='Right'
    
    mapping = {
        1, [1, 1, 2, 2]; % T1: C=Flower@Left, I=Spider@Center
        2, [1, 1, 3, 3]; % T2: C=Flower@Left, I=Airplane@Right
        3, [3, 2, 2, 1]; % T3: C=Airplane@Center, I=Spider@Left
        4, [3, 2, 1, 3]; % T4: C=Airplane@Center, I=Flower@Right
        5, [2, 3, 3, 1]; % T5: C=Spider@Right, I=Airplane@Left
        6, [2, 3, 1, 2]; % T6: C=Spider@Right, I=Flower@Center
    };
    
    % Find the row corresponding to the input trial_type
    idx = find([mapping{:, 1}] == trial_type);
    
    if isempty(idx)
        chosen_object = 'Unknown';
        chosen_location = 'Unknown';
        return;
    end
    
    % Extract the mapping for the current trial type
    data = mapping{idx, 2}; 
    
    % Outcome = 1 (Correct) means the animal chose the C-pair (cols 1 & 2)
    if outcome == 1
        obj_code = data(1);
        loc_code = data(2);
    % Outcome = 0 (Incorrect) means the animal chose the I-pair (cols 3 & 4)
    else 
        obj_code = data(3);
        loc_code = data(4);
    end
    
    % Convert numeric codes back to descriptive strings
    obj_names = {'Flower', 'Spider', 'Airplane'};
    loc_names = {'Left', 'Center', 'Right'};
    
    chosen_object = obj_names{obj_code};
    chosen_location = loc_names{loc_code};
end