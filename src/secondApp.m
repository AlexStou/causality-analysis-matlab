classdef secondApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        MutualInformationButton matlab.ui.control.Button
        CrossCorrelationButton  matlab.ui.control.Button
        GrangerCausalityButton  matlab.ui.control.Button
        TransferEntropyButton   matlab.ui.control.Button
        % CDMI button removed
        PartialTransferEntropyButton matlab.ui.control.Button
        RunButton               matlab.ui.control.Button
        CancelButton            matlab.ui.control.Button
        HelpButton              matlab.ui.control.Button
        SelectedMeasuresLabel   matlab.ui.control.Label
        SelectedMeasuresListBox matlab.ui.control.ListBox
        DeleteSelectedButton    matlab.ui.control.Button
        TimeSeriesData          % Store the time series data
        ParentApp               % Reference to the parent app (app1)
        
        % Mutual Information parameters
        MISelected = false
        MIBins = 10            % Number of bins for discretization
        MILags = 1             % Time lags for delayed dependencies
        
        % Cross-Correlation parameters
        CCSelected = false
        CCLag = 1              % Lag for cross-correlation
        CCSignificance = 0.05  % Significance level
        
        % Granger Causality parameters
        GCSelected = false
        GCOrder = 1            % Model order (number of lags) - start with 1
        GCMakeTest = false     % Compute parametric F-test p-values
        
        % Transfer Entropy parameters
        TESelected = false
        TEEmbedding = 2        % Embedding dimension
        TEDelay = 1            % Time delay
        TENeighbors = 5       % Number of nearest neighbors (k)
        TET = 1               % Prediction horizon T
        
        % CDMI removed
        
        % Partial Transfer Entropy parameters
        PTESelected = false
        PTEEmbedding = 2      % Embedding dimension
        PTELag = 1            % Time delay
        PTENeighbors = 5      % Number of nearest neighbors (k)
        PTET = 1              % Prediction horizon T

        ConditionalGrangerCausalityButton matlab.ui.control.Button
        CGCISelected = false
        CGCIOrder = 1
        CGCIMakeTest = false
    end
    
    properties (Constant)
        % Centralized default parameters
        DEFAULT_MIBins = 10;
        DEFAULT_MILags = 1;
        DEFAULT_CCLag = 1;
        DEFAULT_CCSignificance = 0.05;
        DEFAULT_GCOrder = 1;
        DEFAULT_TEEmbedding = 2;
        DEFAULT_TEDelay = 1;
        % CDMI defaults removed
        DEFAULT_PTEEmbedding = 2;
        DEFAULT_PTELag = 1;
    end
    
    methods (Access = private)
          
        % Button pushed function: MutualInformationButton
        function MutualInformationButtonPushed(app, event)
            % Create and show the Mutual Information Parameters app
            miApp = MutualInformationApp;
            miApp.ParentApp = app;
            miApp.BinsSpinner.Value = app.MIBins;
            miApp.LagsSpinner.Value = app.MILags;
            % Don't automatically select - wait for OK/Run button
            app.propagateParameterToParent('MIBins', app.MIBins);
            app.propagateParameterToParent('MILags', app.MILags);
        end

        % CDMI handler removed

        % Button pushed function: CrossCorrelationButton
        function CrossCorrelationButtonPushed(app, event)
            % Create and show Cross-Correlation Parameters app
            ccApp = CrossCorrelationApp(app);
        end

        % Button pushed function: GrangerCausalityButton
        function GrangerCausalityButtonPushed(app, ~)
            % Open the new GCI parameter dialog (GrangerCausalityApp)
            gciApp = GrangerCausalityApp(app);
        end

        % Button pushed function: TransferEntropyButton
        function TransferEntropyButtonPushed(app, event)
            % Open TE parameter dialog (neighbors, T, m, tau)
            teApp = TransferEntropyApp(app);
        end

        % Button pushed function: PartialTransferEntropyButton
        function PartialTransferEntropyButtonPushed(app, event)
            pteApp = PartialTransferEntropyApp(app);
        end

        % Button pushed function: RunButton
        function RunButtonPushed(app, event)
            % Gather selected measures
            measures = {};
            if app.MISelected
                measures{end+1} = 'MI';
            end
            if app.CCSelected
                measures{end+1} = 'CC';
            end
            if app.GCSelected
                measures{end+1} = 'GC';
            end
            if app.CGCISelected
                measures{end+1} = sprintf('CGCI (Order: %d)', app.CGCIOrder);
            end
            if app.TESelected
                measures{end+1} = 'TE';
            end
            if app.PTESelected
                measures{end+1} = 'PTE';
            end
            if isempty(measures)
                uialert(app.UIFigure, 'Please select at least one measure.', 'Error', 'Icon', 'error');
                return;
            end
            
            % Determine number of variables for performance warnings
            if istable(app.TimeSeriesData)
                numVars = width(app.TimeSeriesData) - 1; % exclude time column
            else
                numVars = size(app.TimeSeriesData, 2);
            end
            
            % Warn about TE with many variables
            if app.TESelected && numVars > 30
                warningMsg = sprintf(['Transfer Entropy with %d variables (%d pairs) may take considerable time.\n\n' ...
                    'Estimated time: %s\n\nDo you want to continue?'], ...
                    numVars, numVars^2, app.estimateTETime(numVars));
                choice = uiconfirm(app.UIFigure, warningMsg, 'Performance Warning', ...
                    'Options', {'Continue', 'Cancel'}, 'DefaultOption', 2, 'Icon', 'warning');
                if strcmp(choice, 'Cancel')
                    return;
                end
            end
            
            % Warn about CGCI with many variables
            if app.CGCISelected && numVars > 40
                warningMsg = sprintf(['Conditional Granger Causality with %d variables may take considerable time.\n\n' ...
                    'Estimated time: %s\n\nDo you want to continue?'], ...
                    numVars, app.estimateCGCITime(numVars));
                choice = uiconfirm(app.UIFigure, warningMsg, 'Performance Warning', ...
                    'Options', {'Continue', 'Cancel'}, 'DefaultOption', 2, 'Icon', 'warning');
                if strcmp(choice, 'Cancel')
                    return;
                end
            end
            
            % Warn about PTE with many variables
            if app.PTESelected && numVars > 20
                warningMsg = sprintf(['Partial Transfer Entropy with %d variables may take a very long time (possibly hours).\n\n' ...
                    'Estimated time: %s\n\nDo you want to continue?'], ...
                    numVars, app.estimatePTETime(numVars));
                choice = uiconfirm(app.UIFigure, warningMsg, 'Performance Warning', ...
                    'Options', {'Continue', 'Cancel'}, 'DefaultOption', 2, 'Icon', 'warning');
                if strcmp(choice, 'Cancel')
                    return;
                end
            end
            
            % Create cancellable progress dialog
            numMeasures = length(measures);
            progressDlg = uiprogressdlg(app.UIFigure, 'Title', 'Computing Measures', ...
                'Message', 'Initializing calculations...', 'Indeterminate', 'on', 'Cancelable', 'on');
            
            try
                % Pass selected measures and parameters to parent app
                results = struct();
                currentMeasure = 0;
                
                if app.MISelected
                    if progressDlg.CancelRequested
                        close(progressDlg);
                        return;
                    end
                    currentMeasure = currentMeasure + 1;
                    progressDlg.Message = sprintf('Calculating Mutual Information (%d/%d)...', currentMeasure, numMeasures);
                    progressDlg.Value = currentMeasure / numMeasures;
                    progressDlg.Indeterminate = 'off';
                    drawnow;
                    miMatrix = app.calculateMutualInformation();
                    results.MI = miMatrix;
                    results.MI_lag = app.MILags;
                end
                if app.CCSelected
                    if progressDlg.CancelRequested
                        close(progressDlg);
                        return;
                    end
                    currentMeasure = currentMeasure + 1;
                    progressDlg.Message = sprintf('Calculating Cross-Correlation (%d/%d)...', currentMeasure, numMeasures);
                    progressDlg.Value = currentMeasure / numMeasures;
                    drawnow;
                    results.CC = app.calculateCrossCorrelation();
                end
                if app.GCSelected
                    if progressDlg.CancelRequested
                        close(progressDlg);
                        return;
                    end
                    currentMeasure = currentMeasure + 1;
                    progressDlg.Message = sprintf('Calculating Granger Causality (%d/%d)...', currentMeasure, numMeasures);
                    progressDlg.Value = currentMeasure / numMeasures;
                    drawnow;
                    % Always clear stale p-values before recalculating GC
                    if ~isempty(app.ParentApp) && isvalid(app.ParentApp) && isprop(app.ParentApp,'MeasureResults') && ~isempty(app.ParentApp.MeasureResults)
                        if isfield(app.ParentApp.MeasureResults,'GC_p')
                            app.ParentApp.MeasureResults = rmfield(app.ParentApp.MeasureResults,'GC_p');
                        end
                        if isfield(app.ParentApp.MeasureResults,'GC_maketest')
                            app.ParentApp.MeasureResults = rmfield(app.ParentApp.MeasureResults,'GC_maketest');
                        end
                    end
                    [gcMat, pMat] = app.calculateGrangerCausality();
                    results.GC = gcMat;
                    % Persist whether F-test was selected
                    results.GC_maketest = logical(isprop(app,'GCMakeTest') && app.GCMakeTest);
                    if ~isempty(pMat) && results.GC_maketest
                        results.GC_p = pMat;
                    end
                end
                if app.TESelected
                    if progressDlg.CancelRequested
                        close(progressDlg);
                        return;
                    end
                    currentMeasure = currentMeasure + 1;
                    if numVars > 30
                        progressDlg.Message = sprintf('Calculating Transfer Entropy (%d/%d)...\nProcessing %d pairs with %d variables.\nClick Cancel to stop.', currentMeasure, numMeasures, numVars^2, numVars);
                    else
                        progressDlg.Message = sprintf('Calculating Transfer Entropy (%d/%d)...', currentMeasure, numMeasures);
                    end
                    progressDlg.Value = currentMeasure / numMeasures;
                    drawnow;
                    results.TE = app.calculateTransferEntropy();
                    if progressDlg.CancelRequested
                        close(progressDlg);
                        return;
                    end
                end
                % CDMI removed
                if app.PTESelected
                    if progressDlg.CancelRequested
                        close(progressDlg);
                        return;
                    end
                    currentMeasure = currentMeasure + 1;
                    if istable(app.TimeSeriesData)
                        numVars = width(app.TimeSeriesData) - 1;
                    else
                        numVars = size(app.TimeSeriesData, 2);
                    end
                    if numVars > 20
                        progressDlg.Message = sprintf('Calculating Partial Transfer Entropy (%d/%d)...\nThis may take a while with %d variables.\nClick Cancel to stop.', currentMeasure, numMeasures, numVars);
                    else
                        progressDlg.Message = sprintf('Calculating Partial Transfer Entropy (%d/%d)...', currentMeasure, numMeasures);
                    end
                    progressDlg.Value = currentMeasure / numMeasures;
                    drawnow;
                    pteResult = app.calculatePartialTransferEntropy();
                    if isempty(pteResult) || all(all(isnan(pteResult)))
                        uialert(app.UIFigure, 'Partial Transfer Entropy could not be computed for the selected data/parameters.', 'Warning', 'Icon', 'warning');
                    end
                    results.PTE = pteResult;
                    if progressDlg.CancelRequested
                        close(progressDlg);
                        return;
                    end
                end
                if app.CGCISelected
                    if progressDlg.CancelRequested
                        close(progressDlg);
                        return;
                    end
                    currentMeasure = currentMeasure + 1;
                    if numVars > 40
                        progressDlg.Message = sprintf('Calculating Conditional Granger Causality (%d/%d)...\nProcessing %d variables.\nClick Cancel to stop.', currentMeasure, numMeasures, numVars);
                    else
                        progressDlg.Message = sprintf('Calculating Conditional Granger Causality (%d/%d)...', currentMeasure, numMeasures);
                    end
                    progressDlg.Value = currentMeasure / numMeasures;
                    drawnow;
                    % Always clear stale p-values before recalculating CGCI
                    if ~isempty(app.ParentApp) && isvalid(app.ParentApp) && isprop(app.ParentApp,'MeasureResults') && ~isempty(app.ParentApp.MeasureResults)
                        if isfield(app.ParentApp.MeasureResults,'CGCI_p')
                            app.ParentApp.MeasureResults = rmfield(app.ParentApp.MeasureResults,'CGCI_p');
                        end
                        if isfield(app.ParentApp.MeasureResults,'CGCI_maketest')
                            app.ParentApp.MeasureResults = rmfield(app.ParentApp.MeasureResults,'CGCI_maketest');
                        end
                    end
                    [cgciMat, pMat] = app.calculateCGCI();
                    results.CGCI = cgciMat;
                    % Persist whether F-test was selected
                    results.CGCI_maketest = logical(isprop(app,'CGCIMakeTest') && app.CGCIMakeTest);
                    if ~isempty(pMat) && results.CGCI_maketest
                        results.CGCI_p = pMat;
                    end
                end
                if ~isempty(app.ParentApp) && isvalid(app.ParentApp)
                    % Merge results into existing MeasureResults instead of replacing
                    if isempty(app.ParentApp.MeasureResults)
                        app.ParentApp.MeasureResults = results;
                    else
                        % Copy all fields from results into MeasureResults
                        resultFields = fieldnames(results);
                        for i = 1:length(resultFields)
                            app.ParentApp.MeasureResults.(resultFields{i}) = results.(resultFields{i});
                        end
                    end
                    if ismethod(app.ParentApp, 'updateMeasuresList')
                        app.ParentApp.updateMeasuresList();
                    end
                    if ismethod(app.ParentApp, 'updateCurrentMeasuresList')
                        app.ParentApp.updateCurrentMeasuresList();
                    end
                end
                
                % Update progress: Complete
                progressDlg.Message = 'Calculations complete!';
                progressDlg.Value = 1;
                pause(0.3); % Brief pause to show completion
                
                % Close progress dialog
                close(progressDlg);
                
                % Update the selected measures list in secondApp immediately after running
                app.updateSelectedMeasuresList();
                % Close the secondApp interface after running
                delete(app.UIFigure);
                
            catch ME
                % Close progress dialog on error
                if exist('progressDlg', 'var') && isvalid(progressDlg)
                    close(progressDlg);
                end
                % Show error to user
                uialert(app.UIFigure, ['Error during calculation: ' ME.message], 'Calculation Error', 'Icon', 'error');
                rethrow(ME);
            end
        end
        
        % Calculate Mutual Information
        function mi = calculateMutualInformation(app)
            % Get data excluding time column
            data = app.TimeSeriesData(:, 2:end);
            varNames = data.Properties.VariableNames;
            nVars = length(varNames);
            
            % MI(i,j) = I(x_i(t); x_j(t+lag)). For lag = 0 the measure is
            % symmetric; for lag > 0 the two directions differ, so every
            % ordered pair is computed. The diagonal is not defined (NaN).
            X = table2array(data);
            mi = NaN(nVars);
            lag = app.MILags;
            for i = 1:nVars
                for j = 1:nVars
                    if i == j
                        continue;
                    end
                    if lag == 0 && j < i
                        mi(i,j) = mi(j,i);   % symmetric at zero lag
                    else
                        mi(i,j) = app.mutualInformation(X(:,i), X(:,j), app.MIBins, lag);
                    end
                end
            end
        end

        % Calculate Transfer Entropy for all pairs using nearest neighbors
        function teMatrix = calculateTransferEntropy(app)
            % Get data excluding time column
            if istable(app.TimeSeriesData)
                dataMatrix = table2array(app.TimeSeriesData(:, 2:end));
            else
                dataMatrix = app.TimeSeriesData;
            end
            if isempty(dataMatrix)
                teMatrix = [];
                return;
            end
            % Parameters
            if ~isprop(app, 'TENeighbors') || isempty(app.TENeighbors)
                app.TENeighbors = 5;
            end
            if ~isprop(app, 'TET') || isempty(app.TET)
                app.TET = 1;
            end
            if isempty(app.TEEmbedding)
                app.TEEmbedding = app.DEFAULT_TEEmbedding;
            end
            if isempty(app.TEDelay)
                app.TEDelay = app.DEFAULT_TEDelay;
            end
            nnei = app.TENeighbors;
            T = app.TET;
            m = app.TEEmbedding;
            tau = app.TEDelay;
            try
                teMatrix = TEnneiAll(dataMatrix, nnei, T, m, tau);
            catch ME
                uialert(app.UIFigure, ['TE failed: ' ME.message], 'Error', 'Icon', 'error');
                teMatrix = NaN(size(dataMatrix,2));
            end
        end
        
        % Mutual Information calculation between two time series
        function mi = mutualInformation(~, x, y, bins, lags)
            % mutualInformation Calculate mutual information between two time series
            %   mi = mutualInformation(x, y, bins, lags) returns the mutual information
            %   between x and y using the specified number of bins and lag.
            %   If bins=0, uses adaptive binning: round(sqrt(n/5))
            %   Formula: I(X;Y) = ΣΣ p(x,y) log₂(p(x,y)/(p(x)p(y)))
            if lags == 0
                % Simultaneous MI - use all data points
                n = length(x);
            else
                % Lagged MI - adjust for time delay
                x = x(1:end-lags);
                y = y(lags+1:end);
                n = length(x);
            end
            
            % Determine number of bins
            if bins == 0
                % Adaptive binning based on data length
                actualBins = max(2, round(sqrt(n/5)));
            else
                actualBins = bins;
            end
            
            % Calculate joint and marginal histograms
            [joint_hist, ~] = histcounts2(x, y, actualBins);
            px = sum(joint_hist, 2) / sum(joint_hist(:));
            py = sum(joint_hist, 1) / sum(joint_hist(:));
            pxy = joint_hist / sum(joint_hist(:));
            
            % Calculate mutual information using basic formula
            % I(X;Y) = ΣΣ p(x,y) log₂(p(x,y)/(p(x)p(y)))
            mi = 0;
            for i = 1:actualBins
                for j = 1:actualBins
                    if pxy(i,j) > 0 && px(i) > 0 && py(j) > 0
                        mi = mi + pxy(i,j) * log2(pxy(i,j) / (px(i) * py(j)));
                    end
                end
            end
            
        end

        % Calculate Granger Causality (GCI) for all pairs
        function [gcMatrix, pMatrix] = calculateGrangerCausality(app)
            % Get data excluding time column
            if istable(app.TimeSeriesData)
                dataMatrix = table2array(app.TimeSeriesData(:, 2:end));
            else
                dataMatrix = app.TimeSeriesData;
            end
            p = app.GCOrder;
            makeTest = false;
            if isprop(app, 'GCMakeTest')
                makeTest = app.GCMakeTest;
            end
            [gcMatrix, pMatrix] = GCinAll(dataMatrix, p, makeTest);
            try
                % Clean numeric artifacts
                % Non-finite values stay NaN (reported to the user);
                % tiny negative values from round-off are set to 0.
                gcMatrix(~isfinite(gcMatrix)) = NaN;
                gcMatrix(gcMatrix < 0) = 0;
                gcMatrix(1:size(gcMatrix,1)+1:end) = NaN;
                % p-values are kept exactly as computed by the F-test
                % (no normalization/clipping). Non-finite stay as NaN.
                if ~isempty(pMatrix)
                    pMatrix(~isfinite(pMatrix)) = NaN;
                end
            catch
            end
        end

        % Button pushed function: CancelButton
        function CancelButtonPushed(app, ~)
            delete(app.UIFigure);
        end

        % Button pushed function: HelpButton
        function HelpButtonPushed(app, ~)
            % Display comprehensive help information
            helpText = sprintf(['Measures Guide\n\n' ...
                '=== MUTUAL INFORMATION (MI) ===\n' ...
                'Purpose: Measures statistical dependence between variables (symmetric).\n' ...
                'Values: 0 (independent) to ∞ (bits). Values >1 are normal.\n' ...
                'Parameters:\n' ...
                '  • Bins: Discretization level (2-100). Use 0 for auto: √(n/5)\n' ...
                '  • Lags: Time delay to analyze delayed dependencies (0-50)\n' ...
                'Usage: Good for undirected relationships, correlation detection.\n' ...
                'Note: Symmetric matrix, diagonal = max self-information.\n\n' ...
                '=== CROSS-CORRELATION (CC) ===\n' ...
                'Purpose: Linear correlation between variables at different lags.\n' ...
                'Values: -1 (perfect negative) to +1 (perfect positive).\n' ...
                'Parameters:\n' ...
                '  • Lag: Time shift to test (0-100)\n' ...
                '  • Significance: α-level for filtering (0.001-0.1)\n' ...
                'Usage: Best for linear relationships. Fast computation.\n' ...
                'Note: Symmetric matrix. Includes significance testing.\n\n' ...
                '=== TRANSFER ENTROPY (TE) ===\n' ...
                'Purpose: Directed information flow from X to Y (asymmetric).\n' ...
                'Values: ≥0 (bits). Higher = stronger causal influence.\n' ...
                'Parameters:\n' ...
                '  • Neighbors (k): NN estimator (3-20). Default: 5\n' ...
                '  • Embedding (m): History length (1-10). Default: 2\n' ...
                '  • Delay (τ): Time lag between embeddings (1-10). Default: 1\n' ...
                '  • Horizon (T): Prediction steps ahead (1-5). Default: 1\n' ...
                'Usage: Detects nonlinear causality. Requires 100+ data points.\n' ...
                'Note: Asymmetric matrix. Computationally intensive.\n\n' ...
                '=== PARTIAL TRANSFER ENTROPY (PTE) ===\n' ...
                'Purpose: Direct TE from X→Y, removing indirect paths via Z.\n' ...
                'Values: ≥0 (bits). Shows direct causal links only.\n' ...
                'Parameters: Same as TE (k, m, τ, T).\n' ...
                'Usage: Network analysis, true causal structure. Very slow!\n' ...
                'Warning: O(K³) complexity in variables K. Use <20 variables. Can take hours.\n' ...
                'Note: Asymmetric. Requires 200+ data points.\n\n' ...
                '=== GRANGER CAUSALITY (GC) ===\n' ...
                'Purpose: Linear predictive causality from X to Y.\n' ...
                'Values: ≥0. Higher = better prediction using X''s past.\n' ...
                'Parameters:\n' ...
                '  • Model Order: AR lag length (1-20). Default: 1\n' ...
                '  • Test: F-test for significance (optional)\n' ...
                '  • Significance: α-level (0.001-0.1). Default: 0.05\n' ...
                'Usage: Fast, interpretable. Assumes linear dynamics.\n' ...
                'Note: Asymmetric matrix. Includes p-values.\n\n' ...
                '=== CONDITIONAL GC (CGCI) ===\n' ...
                'Purpose: GC from X→Y conditioning on all other variables Z.\n' ...
                'Values: ≥0. Direct linear influence only.\n' ...
                'Parameters: Same as GC (order, test type, α).\n' ...
                'Usage: Multivariate networks, removes spurious links.\n' ...
                'Note: Asymmetric. Requires ≥3 variables. Includes p-values.\n\n' ...
                '=== GENERAL RECOMMENDATIONS ===\n' ...
                '• Data Length: MI/CC need 50+ points, TE/PTE need 100-200+\n' ...
                '• Start Simple: Try CC/MI first, then GC, finally TE/PTE\n' ...
                '• Parameters: Use defaults initially, adjust if needed\n' ...
                '• NaN Values: Indicate insufficient data after embedding/lag\n' ...
                '• Visualization: Network plots for ≤10 vars, tables otherwise\n' ...
                '• Significance: Use p-values (GC/CGCI) or CC thresholds\n' ...
                '• Performance: PTE is slowest. Expect minutes to hours.\n\n' ...
                'For more information, consult the documentation.']);
            
            % Create resizable help dialog
            dlg = uifigure('Name', 'Help - Measures Guide', 'Position', [100 100 800 650], 'Resize', 'on', 'AutoResizeChildren', 'off');
            txt = uitextarea(dlg, 'Value', helpText, 'Editable', 'off', ...
                'Position', [10 50 780 590], 'FontSize', 12);
            closeBtn = uibutton(dlg, 'push', 'Text', 'Close', ...
                'Position', [350 10 100 30], ...
                'ButtonPushedFcn', @(~,~) delete(dlg));
            % Make text area resize with window
            dlg.SizeChangedFcn = @(src,~) set(txt, 'Position', [10 50 src.Position(3)-20 src.Position(4)-60]);
        end
        
        % Propagate parameter to parent app
        function propagateParameterToParent(app, paramName, value)
            % propagateParameterToParent Helper to propagate parameter changes to parent app if it exists
            if ~isempty(app.ParentApp) && isprop(app.ParentApp, paramName)
                app.ParentApp.(paramName) = value;
            end
        end
        
        % Button pushed function: OKButton
        function OKButtonPushed(app, event)
            % Called when OK is pressed in secondApp
            % Existing logic...
            % Update selected measures list to immediately reflect choices
            app.updateSelectedMeasuresList();
        end
        
        % Calculate Partial Transfer Entropy
        function result = calculatePartialTransferEntropy(app)
            % Calculate Partial Transfer Entropy (PTE) for all pairs (X, Y), conditioning on all other variables Z using NN
            if istable(app.TimeSeriesData)
                dataMatrix = table2array(app.TimeSeriesData(:, 2:end));
            else
                dataMatrix = app.TimeSeriesData;
            end
            if isempty(dataMatrix)
                result = [];
                return;
            end
            m = app.PTEEmbedding;
            tau = app.PTELag;
            nnei = app.PTENeighbors;
            T = app.PTET;
            try
                result = PTEnneiAll(dataMatrix, nnei, T, m, tau);
            catch ME
                uialert(app.UIFigure, ['PTE failed: ' ME.message], 'Error', 'Icon', 'error');
                result = NaN(size(dataMatrix,2));
            end
        end

        % Estimate CGCI computation time
        function timeStr = estimateCGCITime(~, numVars)
            % Rough estimate: CGCI scales with n^2 and model order
            % Based on empirical testing: 30 vars ≈ 20s, 50 vars ≈ 1min, 80 vars ≈ 5min
            if numVars <= 30
                timeStr = '< 30 seconds';
            elseif numVars <= 50
                timeStr = '1-2 minutes';
            elseif numVars <= 80
                timeStr = '3-7 minutes';
            elseif numVars <= 100
                timeStr = '8-15 minutes';
            else
                timeStr = '> 15 minutes';
            end
        end

        % Estimate TE computation time
        function timeStr = estimateTETime(~, numVars)
            % Rough estimate: TE scales as O(n^2) for all pairs
            % Based on empirical testing: 20 vars ≈ 10s, 40 vars ≈ 1min, 60 vars ≈ 5min, 80 vars ≈ 15min
            if numVars <= 20
                timeStr = '< 15 seconds';
            elseif numVars <= 30
                timeStr = '30 seconds - 1 minute';
            elseif numVars <= 40
                timeStr = '1-3 minutes';
            elseif numVars <= 60
                timeStr = '5-10 minutes';
            elseif numVars <= 80
                timeStr = '10-20 minutes';
            elseif numVars <= 100
                timeStr = '20-40 minutes';
            else
                timeStr = '> 40 minutes';
            end
        end

        % Estimate PTE computation time
        function timeStr = estimatePTETime(~, numVars)
            % Rough estimate: PTE scales roughly as O(n^2.5) due to conditioning
            % Based on empirical testing: 10 vars ≈ 5s, 20 vars ≈ 30s, 40 vars ≈ 5min, 80 vars ≈ 1-2 hours
            if numVars <= 10
                timeStr = '< 10 seconds';
            elseif numVars <= 20
                timeStr = '30 seconds - 1 minute';
            elseif numVars <= 30
                timeStr = '2-5 minutes';
            elseif numVars <= 50
                timeStr = '10-30 minutes';
            elseif numVars <= 80
                timeStr = '1-2 hours';
            else
                timeStr = '> 2 hours (not recommended)';
            end
        end

        % Button pushed function: ConditionalGrangerCausalityButton
        function ConditionalGrangerCausalityButtonPushed(app, ~)
            % Open the CGCI parameter dialog
            cgciApp = ConditionalGrangerCausalityApp(app);
        end

        % Calculate Conditional Granger Causality Index (CGCI) for all pairs
        function [cgciMatrix, pMatrix] = calculateCGCI(app)
            % Get data excluding time column
            if istable(app.TimeSeriesData)
                dataMatrix = table2array(app.TimeSeriesData(:, 2:end));
            else
                dataMatrix = app.TimeSeriesData;
            end
            p = app.CGCIOrder;
            makeTest = false;
            if isprop(app, 'CGCIMakeTest')
                makeTest = app.CGCIMakeTest;
            end
            [cgciMatrix, pMatrix] = CGCinall(dataMatrix, p, makeTest);
            try
                % Clean numeric artifacts
                % Non-finite values stay NaN (reported to the user);
                % tiny negative values from round-off are set to 0.
                cgciMatrix(~isfinite(cgciMatrix)) = NaN;
                cgciMatrix(cgciMatrix < 0) = 0;
                cgciMatrix(1:size(cgciMatrix,1)+1:end) = NaN;
                % p-values are kept exactly as computed by the F-test
                % (no normalization/clipping). Non-finite stay as NaN.
                if ~isempty(pMatrix)
                    pMatrix(~isfinite(pMatrix)) = NaN;
                end
            catch
            end
        end

        % Button pushed function: DeleteSelectedButton
        function DeleteSelectedButtonPushed(app, event)
            try
                selectedItems = app.SelectedMeasuresListBox.Value;
                
                if isempty(selectedItems) || (ischar(selectedItems) && strcmp(selectedItems, 'No measures selected'))
                    uialert(app.UIFigure, 'Please select measures to delete.', 'No Selection', 'Icon', 'error');
                    return;
                end
                
                % Convert to cell array if single selection
                if ischar(selectedItems)
                    selectedItems = {selectedItems};
                end
                
                % Identify which measures to deselect based on selected items
                for i = 1:length(selectedItems)
                    item = selectedItems{i};
                    if contains(item, 'Mutual Information')
                        app.MISelected = false;
                    elseif contains(item, 'Cross-Correlation')
                        app.CCSelected = false;
                    elseif contains(item, 'Granger Causality Index') && ~contains(item, 'CGCI')
                        app.GCSelected = false;
                    elseif contains(item, 'CGCI')
                        app.CGCISelected = false;
                    elseif contains(item, 'Transfer Entropy') && ~contains(item, 'Partial')
                        app.TESelected = false;
                    elseif contains(item, 'Partial Transfer Entropy')
                        app.PTESelected = false;
                    end
                end
                
                % Update the display
                app.updateSelectedMeasuresList();
                
            catch ME
                uialert(app.UIFigure, ['Error deleting measures: ' ME.message], 'Error', 'Icon', 'error');
            end
        end
    end

    methods (Access = public)

        % Construct app
        function app = secondApp
            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
        
        % Update the selected measures list
        function updateSelectedMeasuresList(app)
            measures = {};
            if app.MISelected
                if app.MIBins == 0
                    measures{end+1} = sprintf('Mutual Information (Bins: Auto, Lags: %d)', app.MILags);
                else
                    measures{end+1} = sprintf('Mutual Information (Bins: %d, Lags: %d)', app.MIBins, app.MILags);
                end
            end
            if app.CCSelected
                measures{end+1} = sprintf('Cross-Correlation (Lag: %d, Significance: %.2f)', app.CCLag, app.CCSignificance);
            end
            if app.GCSelected
                if isprop(app,'GCMakeTest') && app.GCMakeTest
                    measures{end+1} = sprintf('Granger Causality Index (Order: %d, p-values)', app.GCOrder);
                else
                    measures{end+1} = sprintf('Granger Causality Index (Order: %d)', app.GCOrder);
                end
            end
            if app.CGCISelected
                if isprop(app,'CGCIMakeTest') && app.CGCIMakeTest
                    measures{end+1} = sprintf('CGCI (Order: %d, p-values)', app.CGCIOrder);
                else
                    measures{end+1} = sprintf('CGCI (Order: %d)', app.CGCIOrder);
                end
            end
            if app.TESelected
                measures{end+1} = sprintf('Transfer Entropy (k: %d, T: %d, m: %d, tau: %d)', app.TENeighbors, app.TET, app.TEEmbedding, app.TEDelay);
            end
            % CDMI removed
            if app.PTESelected
                measures{end+1} = sprintf('Partial Transfer Entropy (k: %d, T: %d, m: %d, tau: %d)', app.PTENeighbors, app.PTET, app.PTEEmbedding, app.PTELag);
            end
            if isempty(measures)
                measures = {'No measures selected'};
            end
            app.SelectedMeasuresListBox.Items = measures;
        end
        
        % Calculate Cross-Correlation
        function result = calculateCrossCorrelation(app)
            % Get data (excluding time column if present)
            if istable(app.TimeSeriesData)
                dataMatrix = table2array(app.TimeSeriesData(:, 2:end));
            else
                dataMatrix = app.TimeSeriesData;
            end
            if isempty(dataMatrix)
                result = [];
                return;
            end
            [n, nVars] = size(dataMatrix);
            lagVal = round(app.CCLag); % user-specified exact lag (can be 0 or positive)
            if lagVal < 0
                lagVal = 0; % enforce non-negative lag in UI semantics
            end

            % Outputs (directional):
            % CC(i,j) = corr(x_i(t), y_j(t+lag))  -> +lag entry
            % CC(j,i) = corr(y_j(t), x_i(t+lag))  -> -lag entry
            ccMatrix     = zeros(nVars);   % signed corr at specified lag (directional)
            ccMatrix(1:nVars+1:end) = NaN; % diagonal not defined
            ccLagMatrix  = lagVal * ones(nVars);   % uniform lag used
            ccAbs        = zeros(nVars);   % absolute value for convenience

            if lagVal == 0
                % Simple Pearson correlations at zero lag
                for i = 1:nVars
                    xi = dataMatrix(:, i);
                    for j = 1:nVars
                        yj = dataMatrix(:, j);
                        if i == j
                            continue;   % diagonal not defined
                        end
                        if all(xi==xi(1)) || all(yj==yj(1))
                            cij = 0;    % zero variance: correlation not defined
                        else
                            cM = corrcoef(xi, yj);
                            cij = cM(1,2);
                        end
                        if ~isfinite(cij), cij = 0; end
                        ccMatrix(i,j) = cij;
                        ccAbs(i,j)    = abs(cij);
                    end
                end
            else
                % Compute directional lagged correlations explicitly for clarity
                L = lagVal;
                for i = 1:nVars-1
                    xi = dataMatrix(:, i);
                    for j = i+1:nVars
                        yj = dataMatrix(:, j);
                        % x -> y at +L: corr(x(1:end-L), y(1+L:end))
                        if numel(xi) > L && numel(yj) > L
                            x1 = xi(1:end-L); y1 = yj(1+L:end);
                            if all(x1==x1(1)) || all(y1==y1(1))
                                cijPos = 0;
                            else
                                cM = corrcoef(x1, y1);
                                cijPos = cM(1,2);
                            end
                        else
                            cijPos = 0;
                        end
                        % y -> x at +L: corr(y(1:end-L), x(1+L:end))
                        if numel(xi) > L && numel(yj) > L
                            y2 = yj(1:end-L); x2 = xi(1+L:end);
                            if all(y2==y2(1)) || all(x2==x2(1))
                                cijNeg = 0;
                            else
                                cM = corrcoef(y2, x2);
                                cijNeg = cM(1,2);
                            end
                        else
                            cijNeg = 0;
                        end
                        if ~isfinite(cijPos), cijPos = 0; end
                        if ~isfinite(cijNeg), cijNeg = 0; end
                        ccMatrix(i,j) = cijPos;  % x_i -> y_j at +lag
                        ccMatrix(j,i) = cijNeg;  % y_j -> x_i at +lag
                        ccAbs(i,j)    = abs(cijPos);
                        ccAbs(j,i)    = abs(cijNeg);
                    end
                end

            end

            % Store auxiliary outputs in parent results if available
            try
                if ~isempty(app.ParentApp) && isvalid(app.ParentApp)
                    app.ParentApp.MeasureResults.CC_lagUsed = lagVal;
                    app.ParentApp.MeasureResults.CC_abs     = ccAbs;
                end
            catch
            end

            % Significance testing at this lag (two-sided t-test for Pearson r)
            try
                alpha = app.CCSignificance;
                if ~isempty(alpha) && isnumeric(alpha) && isfinite(alpha) && alpha > 0 && alpha < 1
                    % Effective sample size for correlation at lag L ~ n-L
                    nEff = max(3, n - lagVal); % need at least 3 to have df>=1
                    df = nEff - 2;
                    % Clip to avoid infinities in t-stat at r=±1 (diagonal handled below)
                    rClip = min(max(ccMatrix, -0.999999), 0.999999);
                    tstat = abs(rClip) .* sqrt((nEff - 2) ./ max(1e-12, (1 - rClip.^2)));
                    % Two-sided p-values
                    pMat = 2 * (1 - tcdf(tstat, df));
                    % Diagonal not defined
                    pMat(1:size(pMat,1)+1:end) = NaN;
                    CC_sig = pMat < alpha;   % NaN -> false
                    % Critical correlation (two-sided) corresponding to alpha
                    tcrit = tinv(1 - alpha/2, df);
                    rCrit = sqrt(tcrit.^2 / (tcrit.^2 + df));
                    if ~isempty(app.ParentApp) && isvalid(app.ParentApp)
                        % Initialize MeasureResults if it doesn't exist
                        if ~isfield(app.ParentApp, 'MeasureResults') || isempty(app.ParentApp.MeasureResults)
                            app.ParentApp.MeasureResults = struct();
                        end
                        app.ParentApp.MeasureResults.CC_p   = pMat;
                        app.ParentApp.MeasureResults.CC_sig = CC_sig;
                        app.ParentApp.MeasureResults.CC_thr = rCrit; % scalar threshold at this lag
                        app.ParentApp.MeasureResults.CC_lagUsed = lagVal; % Store the lag used
                        app.ParentApp.MeasureResults.CC_alpha = alpha; % Store alpha for display
                    end
                end
            catch ME
                % swallow error; keep CC results without significance if it fails
            end

            % Return the signed correlation at specified lag
            result = ccMatrix;
        end
    end

    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)
            % Create UIFigure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 600 400];
            app.UIFigure.Name = 'Select Measures';

            % Create MutualInformationButton
            app.MutualInformationButton = uibutton(app.UIFigure, 'push');
            app.MutualInformationButton.ButtonPushedFcn = createCallbackFcn(app, @MutualInformationButtonPushed, true);
            app.MutualInformationButton.Position = [50 320 150 22];
            app.MutualInformationButton.Text = 'Mutual Information';

            % Create CrossCorrelationButton
            app.CrossCorrelationButton = uibutton(app.UIFigure, 'push');
            app.CrossCorrelationButton.ButtonPushedFcn = createCallbackFcn(app, @CrossCorrelationButtonPushed, true);
            app.CrossCorrelationButton.Position = [50 280 150 22];
            app.CrossCorrelationButton.Text = 'Cross-Correlation';

            % Create GrangerCausalityButton
            app.GrangerCausalityButton = uibutton(app.UIFigure, 'push');
            app.GrangerCausalityButton.ButtonPushedFcn = createCallbackFcn(app, @GrangerCausalityButtonPushed, true);
            app.GrangerCausalityButton.Position = [50 240 150 22];
            app.GrangerCausalityButton.Text = 'Granger Causality Index';

            % Create ConditionalGrangerCausalityButton
            app.ConditionalGrangerCausalityButton = uibutton(app.UIFigure, 'push');
            app.ConditionalGrangerCausalityButton.ButtonPushedFcn = createCallbackFcn(app, @ConditionalGrangerCausalityButtonPushed, true);
            app.ConditionalGrangerCausalityButton.Position = [50 200 150 22];
            app.ConditionalGrangerCausalityButton.Text = 'CGCI';

            % Create TransferEntropyButton
            app.TransferEntropyButton = uibutton(app.UIFigure, 'push');
            app.TransferEntropyButton.ButtonPushedFcn = createCallbackFcn(app, @TransferEntropyButtonPushed, true);
            app.TransferEntropyButton.Position = [50 160 150 22];
            app.TransferEntropyButton.Text = 'Transfer Entropy';

            % CDMI button removed

            % Create PartialTransferEntropyButton (moved up to close gap after removing CDMI)
            app.PartialTransferEntropyButton = uibutton(app.UIFigure, 'push');
            app.PartialTransferEntropyButton.ButtonPushedFcn = createCallbackFcn(app, @PartialTransferEntropyButtonPushed, true);
            app.PartialTransferEntropyButton.Position = [50 120 150 22];
            app.PartialTransferEntropyButton.Text = 'Partial Transfer Entropy';

            % Create SelectedMeasuresLabel
            app.SelectedMeasuresLabel = uilabel(app.UIFigure);
            app.SelectedMeasuresLabel.Position = [250 350 150 22];
            app.SelectedMeasuresLabel.Text = 'Selected Measures:';

            % Create SelectedMeasuresListBox
            app.SelectedMeasuresListBox = uilistbox(app.UIFigure);
            app.SelectedMeasuresListBox.Position = [250 180 300 160];
            app.SelectedMeasuresListBox.Items = {'No measures selected'};
            app.SelectedMeasuresListBox.Multiselect = 'on';

            % Create DeleteSelectedButton
            app.DeleteSelectedButton = uibutton(app.UIFigure, 'push');
            app.DeleteSelectedButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteSelectedButtonPushed, true);
            app.DeleteSelectedButton.Position = [250 150 100 22];
            app.DeleteSelectedButton.Text = 'Delete Selected';

            % Create RunButton
            app.RunButton = uibutton(app.UIFigure, 'push');
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @RunButtonPushed, true);
            app.RunButton.Position = [250 50 100 22];
            app.RunButton.Text = 'Run';

            % Create CancelButton
            app.CancelButton = uibutton(app.UIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            app.CancelButton.Position = [450 50 100 22];
            app.CancelButton.Text = 'Cancel';

            % Create HelpButton
            app.HelpButton = uibutton(app.UIFigure, 'push');
            app.HelpButton.ButtonPushedFcn = createCallbackFcn(app, @HelpButtonPushed, true);
            app.HelpButton.Position = [360 50 80 22];
            app.HelpButton.Text = 'Help';
            app.HelpButton.Tooltip = 'Show detailed information about all measures';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end
end