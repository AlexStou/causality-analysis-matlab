function generate_economic_data(filename, N)
% GENERATE_ECONOMIC_DATA  Παραγωγή ρεαλιστικών συνθετικών οικονομικών δεδομένων
% με ΓΝΩΣΤΗ αιτιακή δομή, σε μορφή συμβατή με την εφαρμογή (Time + στήλες, tab).
%
%   generate_economic_data()                 -> 'economic_data.txt', 2000 σημεία
%   generate_economic_data(filename, N)
%
% Αιτιακή δομή (πραγματική / ground truth):
%   Oil(t)   : κοινός εξωγενής οδηγός (τιμή πετρελαίου, AR με όγκους volatility)
%   Rate     : επιτόκιο, αντιδρά στον πληθωρισμό -> Oil -> Rate
%   Invest   : επένδυση, μειώνεται με το επιτόκιο   -> Rate -> Invest
%   GDP      : ΑΕΠ, αυξάνεται με την επένδυση        -> Invest -> GDP
%   Stock    : χρηματιστηριακός δείκτης, ακολουθεί GDP & Oil -> {GDP,Oil} -> Stock
%
% Έμμεσες σχέσεις προς επαλήθευση:
%   Rate -> GDP  (έμμεση, μέσω Invest): την βρίσκει το ζευγαρικό GC/TE,
%                την εξαλείφει το CGCI/PTE.
%   Φαινομενική Rate <-> Stock μέσω του κοινού οδηγού Oil.

    if nargin < 1 || isempty(filename), filename = 'economic_data.txt'; end
    if nargin < 2 || isempty(N),        N = 2000;                       end

    rng(42);                       % αναπαραγωγιμότητα
    burn = 200;                    % σημεία προθέρμανσης (απορρίπτονται)
    T = N + burn;

    % --- Προδιαγραφές μεταβλητών ---
    Oil    = zeros(T,1);
    Rate   = zeros(T,1);
    Invest = zeros(T,1);
    GDP    = zeros(T,1);
    Stock  = zeros(T,1);

    % Αρχικές τιμές (ρεαλιστικά επίπεδα)
    Oil(1:2)    = 70;     % $/βαρέλι
    Rate(1:2)   = 3;      % %
    Invest(1:2) = 100;
    GDP(1:2)    = 100;
    Stock(1:2)  = 1000;

    % GARCH-τύπου μεταβλητή διακύμανση για το πετρέλαιο (volatility clustering)
    sigma = 1.5*ones(T,1);
    a0 = 0.2; a1 = 0.1; b1 = 0.85;   % GARCH(1,1)
    eOilPrev = 0;

    for t = 3:T
        % --- Κοινός οδηγός: τιμή πετρελαίου (AR(1) γύρω από ~70 + volatility) ---
        sigma(t) = sqrt(a0 + a1*eOilPrev^2 + b1*sigma(t-1)^2);
        eOil = sigma(t) * randn;
        Oil(t) = 70 + 0.92*(Oil(t-1) - 70) + eOil;
        eOilPrev = eOil;

        % --- Επιτόκιο: αδράνεια + αντίδραση στις αυξήσεις πετρελαίου (Oil -> Rate) ---
        Rate(t) = 0.90*Rate(t-1) + 0.04*(Oil(t-1) - 70) + 0.15*randn;
        Rate(t) = max(Rate(t), 0);                    % μη αρνητικό επιτόκιο

        % --- Μακροχρόνια ανοδική τάση + επιχειρηματικός κύκλος (εξωγενής είσοδος).
        %     Εισάγεται στην επένδυση και διαδίδεται κατάντη μέσω της πραγματικής
        %     αλυσίδας Invest -> GDP -> Stock, χωρίς να αλλοιώνει την αιτιακή δομή. ---
        bc = 0.02*t + 8*sin(2*pi*t/250);
        % --- Επένδυση: αδράνεια - επίδραση επιτοκίου (Rate -> Invest) + κύκλος ---
        Invest(t) = 0.80*Invest(t-1) + 12 - 1.5*Rate(t-1) + 0.20*bc + 0.8*randn;

        % --- ΑΕΠ: αδράνεια + ώθηση από επένδυση (Invest -> GDP) ---
        GDP(t) = 0.85*GDP(t-1) + 0.20*Invest(t-1) - 5 + 0.6*randn;

        % --- Χρηματιστήριο: ακολουθεί ΑΕΠ & πετρέλαιο ({GDP,Oil} -> Stock) ---
        Stock(t) = 0.70*Stock(t-1) + 4.0*GDP(t-1) ...
                 - 2.0*(Oil(t-1) - 70) + 3.0*randn;
    end

    % Απόρριψη προθέρμανσης
    idx  = burn+1:T;
    data = [Oil(idx), Rate(idx), Invest(idx), GDP(idx), Stock(idx)];
    names = {'Oil','Rate','Invest','GDP','Stock'};

    write_dataset(filename, data, names);

    fprintf('Δημιουργήθηκε: %s  (%d σημεία, %d μεταβλητές)\n', ...
            filename, size(data,1), size(data,2));
    fprintf(['Πραγματική δομή: Oil->Rate->Invest->GDP, {GDP,Oil}->Stock\n' ...
             'Έμμεση: Rate->GDP (μέσω Invest). Κοινός οδηγός: Oil.\n']);
end

function write_dataset(filename, data, names)
% Εγγραφή σε μορφή: Time<tab>Name1<tab>...  και αριθμητικά με %.4f
    N = size(data,1);
    fid = fopen(filename, 'w');
    if fid == -1, error('Αδυναμία εγγραφής στο %s', filename); end
    fprintf(fid, 'Time');
    fprintf(fid, '\t%s', names{:});
    fprintf(fid, '\n');
    for t = 1:N
        fprintf(fid, '%d', t);
        fprintf(fid, '\t%.4f', data(t,:));
        fprintf(fid, '\n');
    end
    fclose(fid);
end
