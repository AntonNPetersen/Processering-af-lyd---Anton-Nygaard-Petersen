function schroederReverb3()
    % --- UI Setup ---
    fig = figure('Name', 'Schroeder Reverb', 'NumberTitle', 'off', 'Position', [300, 200, 400, 250]); % Smaller figure, no title bar number
    movegui(fig, 'center'); % Center the figure on the screen

    % Audio File Loading
    uicontrol(fig, 'Style', 'text', 'String', 'Audio File:', 'Position', [20, 210, 80, 20]);
    audioFileEdit = uicontrol(fig, 'Style', 'edit', 'Position', [100, 210, 200, 20]);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Load', 'Position', [310, 210, 50, 20], 'Callback', @loadAudio);

    % Play/Pause Controls
    playButton = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Play', 'Position', [20, 170, 50, 20], 'Callback', @playAudio);
    pauseButton = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Pause', 'Position', [80, 170, 50, 20], 'Callback', @pauseAudio);
    
    % Reverb Intensity Slider
    uicontrol(fig, 'Style', 'text', 'String', 'Reverb Intensity:', 'Position', [20, 130, 120, 20]);
    reverbIntensitySlider = uicontrol(fig, 'Style', 'slider', 'Min', 0, 'Max', 2, 'Value', 0.5, 'Position', [140, 135, 200, 20]);

    % Dry/Wet Mix Slider (with label)
    dryWetLabel = uicontrol(fig, 'Style', 'text', 'String', 'Dry/Wet Mix:', 'Position', [20, 90, 100, 20]);
    dryWetSlider = uicontrol(fig, 'Style', 'slider', 'Min', 0, 'Max', 2, 'Value', 0.5, 'Position', [140, 95, 200, 20]); 
    
    % --- Audio Variables ---
    x = []; 
    Fs = []; 
    player = []; 
    y = []; 

    % --- Callback Functions ---
    function loadAudio(~, ~)
        [filename, pathname] = uigetfile({'*.mp3;*.wav;*.ogg', 'Audio Files (*.mp3, *.wav, *.ogg)'}, 'Select Audio File');
        if isequal(filename, 0) || isequal(pathname, 0)
            return;  % User cancelled
        end
        fullpath = fullfile(pathname, filename); % Construct the full file path
        [x, Fs] = audioread(fullfile(pathname, filename));
        if size(x, 2) > 1
            x = mean(x, 2); % Convert to mono if stereo
        end
        updateReverb(); % Apply initial reverb settings
    end

    function playAudio(~, ~)
        if ~isempty(y) && (isempty(player) || ~isplaying(player))
            player = audioplayer(y, Fs); % Create or reuse audio player
            play(player); 
        end
    end

    function pauseAudio(~, ~)
        if ~isempty(player) && isplaying(player)
            pause(player); 
        end
    end

    % --- Callback for Slider Changes ---
    function updateReverb(~, ~) 
        % Get slider values
        reverbIntensity = reverbIntensitySlider.Value;
        dryWet = dryWetSlider.Value;

        % Preset filter parameters based on reverbIntensity
        combDelays = round([500, 800, 1200, 1500] * (1 + reverbIntensity));  % Four delays
        combGains = [0.7, 0.6, 0.5, 0.4] * (1 - 0.2 * reverbIntensity);     % Four gains
        combMixes = [0.5, 0.4, 0.3, 0.2] * (1 - 0.3 * reverbIntensity);    % Four mixes
        allpassDelays = round([50, 80] * (1 + 0.3 * reverbIntensity));
        allpassGains = [0.5, 0.7] * (1 - 0.1 * reverbIntensity);   

        % Process audio only if loaded
        if ~isempty(x)
            y = processAudio(x, combDelays, combGains, combMixes, allpassDelays, allpassGains, dryWet);

            % Update audio player if playing
            if ~isempty(player) && isplaying(player)
                stop(player); 
                player = audioplayer(y, Fs); 
                play(player);
            end
        end
    end

    % --- The processAudio Function ---
    function y = processAudio(x, combDelays, combGains, combMixes, allpassDelays, allpassGains, dryWet)
        numSamples = length(x);
        numCombSets = 4; % Four sets of comb filters
        yComb = zeros(numSamples, numCombSets); 
    
        % Comb Filters (Four Sets)
        for i = 1:numCombSets
            for n = combDelays(i)+1 : numSamples
                yComb(n,i) = x(n) + combGains(i) * yComb(n - combDelays(i), i);
            end
        end
        yComb = sum(yComb .* combMixes, 2); 
    
        % Allpass Filters (Two in Series)
        yAllpass1 = zeros(numSamples, 1);
        yAllpass2 = zeros(numSamples, 1);
        for n = allpassDelays(1)+1 : numSamples
            yAllpass1(n) = allpassGains(1) * yComb(n) + yComb(n - allpassDelays(1)) - allpassGains(1) * yAllpass1(n - allpassDelays(1));
        end
        for n = allpassDelays(2)+1 : numSamples
            yAllpass2(n) = allpassGains(2) * yAllpass1(n) + yAllpass1(n - allpassDelays(2)) - allpassGains(2) * yAllpass2(n - allpassDelays(2));
        end
    
        y = dryWet * yAllpass2 + (1 - dryWet) * x;
        end

    % --- Attach Callbacks ---
    reverbIntensitySlider.Callback = @updateReverb;
    dryWetSlider.Callback = @updateReverb;
end
