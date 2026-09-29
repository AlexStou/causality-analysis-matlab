function generate_engineering_data(filename, N)
% GENERATE_ENGINEERING_DATA  Παραγωγή ρεαλιστικών συνθετικών δεδομένων μηχανικού
% με ΓΝΩΣΤΗ αιτιακή δομή, σε μορφή συμβατή με την εφαρμογή (Time + στήλες, tab).
%
%   generate_engineering_data()                 -> 'engineering_data.txt', 3000 σημεία
%   generate_engineering_data(filename, N)
%
% Φυσικό σενάριο: υδραυλικό/θερμικό κύκλωμα με αισθητήρες σε σειρά.
%   Pump  : ταχύτητα αντλίας (εξωγενής οδηγός, βηματικές αλλαγές + θόρυβος)
%   Flow  : παροχή, ακολουθεί την αντλία            -> Pump -> Flow
%   Press : πίεση, εξαρτάται από την παροχή          -> Flow -> Press
%   Temp1 : θερμοκρασία ανάντη, οδηγείται από πίεση  -> Press -> Temp1
%   Temp2 : θερμοκρασία κατάντη (διάχυση θερμότητας) -> Temp1 -> Temp2
%   Vib   : δόνηση, εξαρτάται απευθείας από αντλία    -> Pump -> Vib
%
% Δομή προς επαλήθευση:
%   Αλυσίδα διάχυσης Press->Temp1->Temp2: το Press->Temp2 είναι ΕΜΜΕΣΟ
%       (το βρίσκει το ζευγαρικό GC/TE, το εξαλείφει το CGCI/PTE).
%   Κοινός οδηγός Pump -> {Flow, Vib}: φαινομενική σχέση Flow<->Vib.
%   Έντονη μη γραμμικότητα στη δόνηση (Vib ~ Pump^2) -> εντοπίζεται από MI/TE,
%       όχι από CC/GC.

    if nargin < 1 || isempty(filename), filename = 'engineering_data.txt'; end
    if nargin < 2 || isempty(N),        N = 3000;                          end

    rng(7);                        % αναπαραγωγιμότητα
    burn = 300;
    T = N + burn;

    Pump  = zeros(T,1);
    Flow  = zeros(T,1);
    Press = zeros(T,1);
    Temp1 = zeros(T,1);
    Temp2 = zeros(T,1);
    Vib   = zeros(T,1);

    % Αρχικά επίπεδα λειτουργίας
    Pump(1:2)  = 1500;   % RPM
    Flow(1:2)  = 50;     % L/min
    Press(1:2) = 3;      % bar
    Temp1(1:2) = 60;     % C
    Temp2(1:2) = 55;     % C
    Vib(1:2)   = 0.5;    % mm/s

    % Προφίλ αντλίας: βηματικές μεταβολές (setpoints) + θόρυβος
    setpoint = 1500;
    for t = 3:T
        if mod(t,150) == 0
            setpoint = 1000 + 1000*rand;         % έντονα βήματα κάθε ~150 βήματα
        end
        % --- Αντλία: επαναφορά προς setpoint + θόρυβος (εξωγενής) ---
        Pump(t) = Pump(t-1) + 0.05*(setpoint - Pump(t-1)) + 8*randn;

        % --- Παροχή: αναλογική στην αντλία με αδράνεια (Pump -> Flow) ---
        Flow(t) = 0.75*Flow(t-1) + 0.012*Pump(t-1) + 0.4*randn;

        % --- Πίεση: εξαρτάται από την παροχή (Flow -> Press) ---
        Press(t) = 0.70*Press(t-1) + 0.04*Flow(t-1) + 0.05*randn;

        % --- Θερμοκρασία ανάντη: οδηγείται από την πίεση (Press -> Temp1) ---
        Temp1(t) = 0.85*Temp1(t-1) + 1.5*Press(t-1) + 0.3*randn;

        % --- Θερμοκρασία κατάντη: διάχυση από Temp1 (Temp1 -> Temp2) ---
        Temp2(t) = 0.80*Temp2(t-1) + 0.18*Temp1(t-1) + 0.3*randn;

        % --- Δόνηση: ΜΗ ΓΡΑΜΜΙΚΗ συνάρτηση της αντλίας (Pump -> Vib) με
        %     ταλάντωση υψηλής συχνότητας (χαρακτηριστική "μηχανική" υπογραφή).
        %     Ο μη γραμμικός όρος ενισχύεται ώστε η σχέση Pump->Vib να παραμένει
        %     σαφώς ανιχνεύσιμη από τα μη γραμμικά μέτρα (MI, TE). ---
        Vib(t) = 0.60*Vib(t-1) + 1e-6*(Pump(t-1)-1500)^2 ...
               + 0.15*sin(2*pi*t/10) + 0.05*randn;
    end

    idx  = burn+1:T;
    data = [Pump(idx), Flow(idx), Press(idx), Temp1(idx), Temp2(idx), Vib(idx)];
    names = {'Pump','Flow','Press','Temp1','Temp2','Vib'};

    write_dataset(filename, data, names);

    fprintf('Δημιουργήθηκε: %s  (%d σημεία, %d μεταβλητές)\n', ...
            filename, size(data,1), size(data,2));
    fprintf(['Πραγματική δομή: Pump->Flow->Press->Temp1->Temp2, Pump->Vib\n' ...
             'Έμμεση: Press->Temp2 (μέσω Temp1). Μη γραμμική: Pump->Vib.\n']);
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
