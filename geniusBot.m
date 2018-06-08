% main method
function geniusBot()
    % imports
    addpath('ScreenCapture/');
    %addpath('tests');
    
    % screen capture
    screen = screencapture(0, [0 50 465 825]);
    %screen = imread('test4.png'); % test image
    [h, w, ~] = size(screen);
    left = round(0.05*w, 0);
    right = round(0.95*w, 0);
    screen = screen(:,left:right,:);
    
    % HQ Card Structure
    HQ.question = questionParser(screen, h);
    HQ.choices = choiceParser(screen, h);
    HQ.hits = [0 0 0];
    if (contains(HQ.question,' not ','IgnoreCase',true))
        HQ.isNot = true;
    else
        HQ.isNot = false;
    end
    [L0, L1, L2, L3] = google(HQ);
    
    HQ = search(HQ, L0, 0);
    if max(HQ.hits) == 0
        HQ = search(HQ, L1, 1);  
        HQ = search(HQ, L2, 2); 
        HQ = search(HQ, L3, 3);
    end
    
    displayAnswer(HQ);
end

% performs ocr on image to determine the question
% @param screen : an image array containing screenshot
% @return q : a string containing question
function q = questionParser(screen, h)
    % Text boundries
    qStart = round(.135 * h, 0);
    qEnd = round(.265 * h, 0);
    % return value
    q = ocr(screen(qStart:qEnd,:,:));
    q = q.Text; 
    q(q == newline) = ' ';
    q = strtrim(q);
end

% performs ocr on image to determine the choices
% @param screen : an image array containing screenshot
% @return choices : cell array of strings containing choices
function choices = choiceParser(screen, h)     
    b = [round(.27 * h, 0), round(.37 * h, 0),...
         round(.47 * h, 0), round(.57 * h, 0)];
    screen = im2bin(screen, 210);
    % choice 1 
    c1 = screen(b(1):b(2),:,:);
    c1 = ocr(c1);
    c1 = c1.Text;
    c1(c1 == newline) = '';
    % choice 2 
    c2 = screen(b(2):b(3),:,:);
    c2 = ocr(c2);
    c2 = c2.Text;
    c2(c2 == newline) = '';
    % choice 3
    c3 = screen(b(3):b(4),:,:);
    c3 = ocr(c3);
    c3 = c3.Text;
    c3(c3 == newline) = '';
    % return
    choices = {c1, c2, c3};
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
    d = dialog('Position',[360 300 640 400],'Name','HQ Bot');
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
        weight = 0.5;
    else
        weight = 2;
    end
    % temp hits array
    hits_t = [0 0 0];
    % search google
    [html, ~] = urlread(link);
    for i = 1:3
        hitCount = length(strfind(lower(html),lower(hq.choices{i})));
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
              ' will | be '];
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