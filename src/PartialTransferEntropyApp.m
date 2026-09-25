classdef PartialTransferEntropyApp < matlab.apps.AppBase
    properties (Access = public)
        UIFigure matlab.ui.Figure
        EmbeddingSpinner matlab.ui.control.Spinner
        LagSpinner matlab.ui.control.Spinner
        NeighborsSpinner matlab.ui.control.Spinner
        HorizonSpinner matlab.ui.control.Spinner
        OKButton matlab.ui.control.Button
        CancelButton matlab.ui.control.Button
        ParentApp % Reference to secondApp
    end
    methods (Access = public)
        function app = PartialTransferEntropyApp(parentApp)
            app.ParentApp = parentApp;
            app.createComponents();
        end
        function OKButtonPushed(app, ~)
            app.ParentApp.PTEEmbedding = app.EmbeddingSpinner.Value;
            app.ParentApp.PTELag = app.LagSpinner.Value;
            app.ParentApp.PTENeighbors = app.NeighborsSpinner.Value;
            app.ParentApp.PTET = app.HorizonSpinner.Value;
            app.ParentApp.PTESelected = true;
            app.ParentApp.updateSelectedMeasuresList();
            delete(app.UIFigure);
        end
        function CancelButtonPushed(app, ~)
            delete(app.UIFigure);
        end
        function createComponents(app)
            app.UIFigure = uifigure('Name', 'Partial Transfer Entropy Parameters', 'Position', [300 300 340 220]);
            uilabel(app.UIFigure, 'Position', [30 170 200 22], 'Text', 'Embedding dimension (m):');
            app.EmbeddingSpinner = uispinner(app.UIFigure, 'Position', [240 170 70 22], 'Limits', [1 10], 'Value', 2, 'Step', 1);
            uilabel(app.UIFigure, 'Position', [30 135 140 22], 'Text', 'Lag (tau):');
            app.LagSpinner = uispinner(app.UIFigure, 'Position', [240 135 70 22], 'Limits', [1 50], 'Value', 1, 'Step', 1);
            uilabel(app.UIFigure, 'Position', [30 100 200 22], 'Text', 'Neighbors (k):');
            app.NeighborsSpinner = uispinner(app.UIFigure, 'Position', [240 100 70 22], 'Limits', [2 100], 'Value', 5, 'Step', 1);
            uilabel(app.UIFigure, 'Position', [30 65 200 22], 'Text', 'Prediction horizon (T):');
            app.HorizonSpinner = uispinner(app.UIFigure, 'Position', [240 65 70 22], 'Limits', [1 10], 'Value', 1, 'Step', 1);
            app.OKButton = uibutton(app.UIFigure, 'push', 'Position', [70 20 80 30], 'Text', 'OK', 'ButtonPushedFcn', @(src, event)app.OKButtonPushed());
            app.CancelButton = uibutton(app.UIFigure, 'push', 'Position', [190 20 80 30], 'Text', 'Cancel', 'ButtonPushedFcn', @(src, event)app.CancelButtonPushed());
        end
    end
end
