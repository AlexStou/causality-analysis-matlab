classdef CrossCorrelationApp < matlab.apps.AppBase
    % Cross-Correlation Parameters Dialog
    properties (Access = public)
        UIFigure matlab.ui.Figure
        LagSpinner matlab.ui.control.Spinner
        SignificanceSpinner matlab.ui.control.Spinner
        OKButton matlab.ui.control.Button
        CancelButton matlab.ui.control.Button
        ParentApp % Reference to secondApp
    end
    methods (Access = public)
        function app = CrossCorrelationApp(parentApp)
            app.ParentApp = parentApp;
            app.createComponents();
        end
        function OKButtonPushed(app, ~)
            app.ParentApp.CCLag = app.LagSpinner.Value;
            app.ParentApp.CCSignificance = app.SignificanceSpinner.Value;
            app.ParentApp.CCSelected = true;
            app.ParentApp.updateSelectedMeasuresList();
            
            % If CC has already been computed, recompute significance with new alpha
            if ~isempty(app.ParentApp.ParentApp) && isfield(app.ParentApp.ParentApp.MeasureResults, 'CC')
                try
                    newCCResult = app.ParentApp.calculateCrossCorrelation();
                    app.ParentApp.ParentApp.MeasureResults.CC = newCCResult;
                catch ME
                    % If recomputation fails, just continue
                    disp(['Warning: Could not recompute CC significance: ' ME.message]);
                end
            end
            
            delete(app.UIFigure);
        end
        function CancelButtonPushed(app, ~)
            delete(app.UIFigure);
        end
        function createComponents(app)
            app.UIFigure = uifigure('Name', 'Cross-Correlation Parameters', 'Position', [300 300 320 180]);
            uilabel(app.UIFigure, 'Position', [20 120 130 22], 'Text', 'Lag:');
            app.LagSpinner = uispinner(app.UIFigure, 'Position', [150 120 100 22], ...
                'Limits', [0 100], 'Value', app.ParentApp.CCLag, 'Step', 1);
            uilabel(app.UIFigure, 'Position', [20 80 130 22], 'Text', 'Significance Level:');
            app.SignificanceSpinner = uispinner(app.UIFigure, 'Position', [150 80 100 22], ...
                'Limits', [0.001 0.5], 'Value', app.ParentApp.CCSignificance, 'Step', 0.001);
            app.OKButton = uibutton(app.UIFigure, 'push', 'Position', [40 20 100 30], 'Text', 'OK', 'ButtonPushedFcn', @(src, event)app.OKButtonPushed());
            app.CancelButton = uibutton(app.UIFigure, 'push', 'Position', [170 20 100 30], 'Text', 'Cancel', 'ButtonPushedFcn', @(src, event)app.CancelButtonPushed());
        end
    end
end
