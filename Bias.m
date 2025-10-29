%location and stimulus bias for RE paper


%% --- Phase 0: Setup and Helper Function Definition ---
% NOTE: The 'deduce_choice.m' function is assumed to be in your path.
% Its signature should be: [obj_choice, loc_choice] = deduce_choice(ttype, outcome)
% And it should return:
% obj_choice: 'Flower', 'Spider', or 'Airplane'
% loc_choice: 'Left', 'Center', or 'Right'
% based on the TrialType_Current (ttype) and Outcome_Current (outcome).


% Define all drug conditions and the number of files for each
drugs = {'saline', 'muscimol', 'nicotine', 'mec'};
% **UPDATE THESE COUNTS based on your actual file names (e.g., saline1.csv to saline8.csv)**
rat_file_counts = containers.Map({'saline', 'muscimol', 'nicotine', 'mec'}, [8, 8, 5, 5]); 
colsToExtract = {'AnimalID', 'TrialAnalysis_Correct', 'TrialAnalysis_TrialType'};

% Function to Calculate Proportion Chosen (Used in Phase 2)
calculate_proportion = @(T, feature_col, feature_value) ...
    sum(strcmp(T.(feature_col), feature_value)) / height(T);


%% --- Phase 1: Combined Data Aggregation for Bias Analysis ---
disp('Phase 1: Aggregating Data and Deducing Choices...');
allData = {};
counter = 1;

for d = 1:length(drugs)
    current_drug = drugs{d};
    num_rats = rat_file_counts(current_drug);
    
    for i = 1:num_rats
        % Assuming file names are sequential (e.g., 'saline1.csv')
        filename = sprintf('%s%d.csv', lower(current_drug), i); 
        
        try
            T = readtable(filename);
            % Ensure the table is not empty before proceeding
            if isempty(T)
                warning(['File ', filename, ' is empty. Skipping.']);
                continue;
            end
        catch ME
            warning(['Could not read file: ', filename, '. Skipping.']);
            continue;
        end
        
        % 1. Extract and rename base columns
        subset = T(:, colsToExtract);
        subset.Properties.VariableNames = {'RatID', 'Outcome_Current', 'TrialType_Current'}; 
        subset.Drug = repmat({current_drug}, height(subset), 1);
        
        % 2. DEDUCE CHOICE: Pre-allocate columns
        num_trials = height(subset);
        choice_objects = cell(num_trials, 1);
        choice_locations = cell(num_trials, 1);
        
        % 3. Apply the deduce_choice function row-by-row
        % Note: You must have 'deduce_choice' defined correctly in your path!
        for row = 1:num_trials
            ttype = subset.TrialType_Current(row);
            outcome = subset.Outcome_Current(row);
            
            [obj_choice, loc_choice] = deduce_choice(ttype, outcome);
            choice_objects{row} = obj_choice;
            choice_locations{row} = loc_choice;
        end
        
        % 4. Add the deduced choice columns back
        subset.Choice_Object_Current = choice_objects;
        subset.Choice_Location_Current = choice_locations;
        
        allData{counter} = subset;
        counter = counter + 1;
    end
end

% Create the final single Master Table for bias analysis
if isempty(allData)
    error('No data files were successfully loaded. Check file names and paths.');
end
MasterTable_Bias = vertcat(allData{:}); 
disp(['Complete MasterTable_Bias created with ', num2str(height(MasterTable_Bias)), ' trials.']);



%% --- Phase 2: Directional Bias Calculation (Proportion Chosen per Rat) ---
disp('Phase 2: Calculating Directional Bias (Proportion Chosen)...');

% Ensure RatID and Drug columns are categorical for proper grouping
MasterTable_Bias.RatID = categorical(MasterTable_Bias.RatID);
MasterTable_Bias.Drug = categorical(MasterTable_Bias.Drug);

% Initialize BiasTable grouped by RatID and Drug
BiasTable_Prop = groupsummary(MasterTable_Bias, {'RatID', 'Drug'});

% Define Feature Parameters
stimuli = {'Flower', 'Spider', 'Airplane'};
locations = {'Left', 'Center', 'Right'};

% --- Calculate and Store Bias Proportions ---
for i = 1:height(BiasTable_Prop)
    current_rat_id = BiasTable_Prop.RatID(i);
    current_drug = BiasTable_Prop.Drug(i);
    
    % Get the subset of trials for the current RatID/Drug group
    T_Group = MasterTable_Bias(MasterTable_Bias.RatID == current_rat_id & ...
                               MasterTable_Bias.Drug == current_drug, :);
    
    % Calculate and store Proportion Chosen for each stimulus
    BiasTable_Prop.Prop_Flower(i)   = calculate_proportion(T_Group, 'Choice_Object_Current', 'Flower');
    BiasTable_Prop.Prop_Spider(i)   = calculate_proportion(T_Group, 'Choice_Object_Current', 'Spider');
    BiasTable_Prop.Prop_Airplane(i) = calculate_proportion(T_Group, 'Choice_Object_Current', 'Airplane');
    
    % Calculate and store Proportion Chosen for each location
    BiasTable_Prop.Prop_Left(i)   = calculate_proportion(T_Group, 'Choice_Location_Current', 'Left');
    BiasTable_Prop.Prop_Center(i) = calculate_proportion(T_Group, 'Choice_Location_Current', 'Center');
    BiasTable_Prop.Prop_Right(i)  = calculate_proportion(T_Group, 'Choice_Location_Current', 'Right');
end

disp('Directional bias calculation complete. BiasTable_Prop ready for LME analysis.');

% Select only the necessary columns for the LME phase
colsToKeep = {'RatID', 'Drug', 'Prop_Flower', 'Prop_Spider', 'Prop_Airplane', 'Prop_Left', 'Prop_Center', 'Prop_Right'};
BiasTable_Prop = BiasTable_Prop(:, colsToKeep);


---

%% --- Phase 3: LME Analysis for Directional Bias (Corrected) ---
disp('Phase 3: Running 6 LME Models for Directional Bias...');

% Define the response variables to iterate over
response_vars = {'Prop_Flower', 'Prop_Spider', 'Prop_Airplane', ...
                 'Prop_Left', 'Prop_Center', 'Prop_Right'};

for i = 1:length(response_vars)
    response_var = response_vars{i};
    disp(['--- Analyzing ', response_var, ' ---']);
    
    % Construct the model formula string: Proportion_Feature ~ Drug + (1|RatID)
    formula_str = [response_var, ' ~ Drug + (1|RatID)'];
    
    try
        % Fit the Linear Mixed-Effects Model
        lme_model = fitlme(BiasTable_Prop, formula_str);
        
        % Run ANOVA
        anova_output = anova(lme_model);
        disp(anova_output);
        
        % Check for significant Drug effect
        drug_row_index = strcmp(anova_output.Term, 'Drug');
        if any(drug_row_index)
            p_val = anova_output.pValue(drug_row_index);
            if p_val < 0.05
                disp(['*** SIGNIFICANT DRUG EFFECT: p = ', num2str(p_val, '%.4f')]);
            else
                 disp(['NO SIGNIFICANT DRUG EFFECT: p = ', num2str(p_val, '%.4f')]);
            end
        else
            disp('Drug term not found in ANOVA output.');
        end
    catch ME
        warning(['LME model failed for ', response_var, ': ', ME.message]);
    end
end
disp('----------------------------------------------------');