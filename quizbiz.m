% LOW POSITION
function quizbiz()
    addpath('ScreenCapture/');
    % HQ Card Structure
    HQ = init();
    [L0, L1, L2, L3] = google(HQ);
    HQ = search(HQ, L0, 0);
    HQ = search(HQ, L1, 1);  
    HQ = search(HQ, L2, 2); 
    HQ = search(HQ, L3, 3);
    displayAnswer(HQ);
end
% init hq question object
% ocr question and answers
function HQ = init()
    s = screencapture(0, [16 270 434 539]);
    
    w1 = ocr(s(100:220,10:end-10,:));
    w2 = ocr(s(225:265,60:end-60,:));    
    w3 = ocr(s(290:330,60:end-60,:));
    w4 = ocr(s(355:395,60:end-60,:));

    HQ.question = strrep(w1.Text, newline, ' ');
    HQ.question(1:2) = '';
    c1 = erase(w2.Text, newline);
    c2 = erase(w3.Text, newline);
    c3 = erase(w4.Text, newline);
    HQ.choices = {c1, c2, c3};
    HQ.hits = [0 0 0];
    HQ.isNot = contains(HQ.question,' NOT ') ...
            || contains(HQ.question,' never ');
end

% displays most likely answer and number of hits
% for each of the choices
% @param obj : HQ struct
function displayAnswer(hq)
    % round
    hq.hits = round(hq.hits./sum(hq.hits)*100, 2);
    % determine answer
    if (hq.isNot)                  % use min if a not question
        [M, I] = min(hq.hits);
    else                            % otherwise just take max
        [M, I] = max(hq.hits);
    end

    if (M == 0 && ~hq.isNot)
        answer = hq.choices{randi(3)}; % guess
        answer = [answer newline 'Sorry. I don''t know. Guess:'];
    else
        answer = [hq.choices{I} ' (' num2str(M) '%)'];
    end
    % display dialog
    d = dialog('Position',[360+450 300-300 640 400],'Name','HQ Bot');
    % question
    uicontrol('Parent',d,...
              'Style','text',...
              'Position',[0 300 640 100],...
              'String', hq.question,...
              'FontSize', 20);
    % answer
    uicontrol('Parent',d,...
             'Style','text',...
             'Position',[0 200 640 100],...
             'String', answer,...
             'FontSize', 40);
    % other answers
    other = [hq.choices{1} '  (' num2str(hq.hits(1)) '%)'...
             newline,...
             hq.choices{2} '  (' num2str(hq.hits(2)) '%)'...
             newline,...
             hq.choices{3} '  (' num2str(hq.hits(3)) '%)'];
    uicontrol('Parent',d,...
              'Style','text',...
              'Position',[0 20 640 100],...
              'String', other,...
              'FontSize', 20);
end
function hq = search(hq, link, mode)
    if mode ~= 0
        weight = 0.25;
    else
        weight = 2;
    end
    % temp hits array
    hits_t = [0 0 0];
    % search google
    if mode == 0
        web(link);
    end
    [html, ~] = urlread(link);
    html = erase(html, ' ');
    for i = 1:3
        hitCount = length(strfind(lower(html),erase(lower(hq.choices{i}),' ')));
        hits_t(i) = hits_t(i) + hitCount * weight;
    end
    % wikipedia search
    wikiBase = 'https://en.wikipedia.org/wiki/';
    wStart = strfind(html, wikiBase);
    if (~isempty(wStart))
        wStart = wStart(1);  % only want first entry
        wEnd = wStart + 30; 
        while (html(wEnd+1) ~= '&')
            wEnd = wEnd + 1;
        end
        [html_w, ~] = urlread(html(wStart:wEnd));
        for i = 1:3
            hitCount = length(strfind(lower(html_w),lower(hq.choices{i})));
            hits_t(i) = hits_t(i) + hitCount * weight;
        end 
    end
    % rebalance weights
    if mode ~= 0
        hits_t(mode) = hits_t(mode) * 0.5;
        rest = setdiff([1,2,3], mode);
        hits_t(rest) = hits_t(rest) * 2.0;
    end
    hq.hits = hq.hits + hits_t.^1.5;
end

% 
% @param hq : an hq struct
% @return L0 : generic google link
% @return L1 : google link with choice 1 weight
% @return L2 : google link with choice 2 weight
% @return L3 : google link with choice 3 weight
function [L0, L1, L2, L3] = google(hq)
    base = ['https://www.google.com/search?source'...
            '=hp&ei=GAMuWv-hCMHbmQGJqquIDw&q='];
    query = hq.question;
    % delete unwanted words, symbols, etc
    query = regexprep(query, '?|,', '');
    filter = [' and | what | are | in | who | the |'...
              ' following | effectively | by | about | of |'...
              ' a | an | had | which | not | by |'...
              'What |Which |Whose |Where | these | was |'...
              'The | to '];
    % run twice on purpose, quirk of regexp
    query = regexprep(query, filter, ' ');
    query = regexprep(query, filter, ' ');
    query = urlencode(query);
    
    L0 = [base query];
    L1 = [L0 '+' urlencode(hq.choices{1})];
    L2 = [L0 '+' urlencode(hq.choices{2})];
    L3 = [L0 '+' urlencode(hq.choices{3})];
end

% encodes any string into url
% @param string : string to be encoded
% @return string : resulted encoded url strinf
function string = urlencode(string)
    string = strtrim(string);          % trim
    string = strrep(string, ' ', '+');    % replaces spaces
    string = strrep(string, '''', '%27'); % replaces apostrophes
    string = strrep(string,'&', '%26'); % replaces ampersands!!
end

% binarizes the image
% @param img : img to be binarized
% @param thresh : uint8 from 0 to 255
% @return img : modified image
function img = im2bin(img, thresh)
    img = rgb2gray(img);
    img(img > thresh) = 255;
    img(img <= thresh) = 0;
end