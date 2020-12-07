function [cx, cy] = grid(sp)
    % sp=space(1-36) occupied in 6x6 grid
    %-----------------------------
    %  1  2  3  10 11 12
    %  4  5  6  13 14 15
    %  7  8  9  16 17 18
    %          +
    % 19 20 21  28 29 30
    % 22 23 24  31 32 33
    % 25 26 27  34 35 36
    %-----------------------------
    
    global cx;
    global cy;
    Xcentre = 0;
    Ycentre = 0;
    
    buffer=0;  % size in pixels of region surrounding the '+' fixation
    cellx=100;    % x-side in pixels
    celly=100;    % y-side in pixels
    gridnmb=3;   % cell units per side
    
    gridAx=Xcentre-20;  % A=lower right corner of space9
    gridAy=Ycentre-20;  
    gridBx=Xcentre+20;  % B=lower left corner of space16
    gridBy=Ycentre-20;
    gridCx=Xcentre-20;  % C=upper right corner of space21
    gridCy=Ycentre+20;
    gridDx=Xcentre+20;  % D=upper left corner of space28
    gridDy=Ycentre+20;
    
    switch sp  
        case 1
            cx=gridAx-(gridnmb*cellx);
            cy=gridAy-(gridnmb*celly);
       	%fprintf('%d, %d\n', cx, cy);
        case 2 
            cx=gridAx-((gridnmb-1)*cellx);
            cy=gridAy-(gridnmb*celly);
        case 3 
            cx=gridAx-((gridnmb-2)*cellx);
            cy=gridAy-(gridnmb*celly);
        case 4 
            cx=gridAx-(gridnmb*cellx);
            cy=gridAy-((gridnmb-1)*celly);
        case 5 
            cx=gridAx-((gridnmb-1)*cellx);
            cy=gridAy-((gridnmb-1)*celly);     
        case 6 
            cx=gridAx-((gridnmb-2)*cellx);
            cy=gridAy-((gridnmb-1)*celly);    
        case 7 
            cx=gridAx-(gridnmb*cellx);
            cy=gridAy-((gridnmb-2)*celly);
        case 8 
            cx=gridAx-((gridnmb-1)*cellx);
            cy=gridAy-((gridnmb-2)*celly);        
        case 9 
            cx=gridAx-((gridnmb-2)*cellx);
            cy=gridAy-((gridnmb-2)*celly);
        case 10  
            cx=gridBx+((gridnmb-3)*cellx);
            cy=gridBy-(gridnmb*celly);
        case 11 
            cx=gridBx+((gridnmb-2)*cellx);
            cy=gridBy-(gridnmb*celly);
        case 12 
            cx=gridBx+((gridnmb-1)*cellx);
            cy=gridBy-(gridnmb*celly);
        case 13 
            cx=gridBx+((gridnmb-3)*cellx);
            cy=gridBy-((gridnmb-1)*celly);
        case 14 
            cx=gridBx+((gridnmb-2)*cellx);
            cy=gridBy-((gridnmb-1)*celly);     
        case 15 
            cx=gridBx+((gridnmb-1)*cellx);
            cy=gridBy-((gridnmb-1)*celly);    
        case 16 
            cx=gridBx+((gridnmb-3)*cellx);
            cy=gridBy-((gridnmb-2)*celly);
        case 17 
            cx=gridBx+((gridnmb-2)*cellx);
            cy=gridBy-((gridnmb-2)*celly);        
        case 18 
            cx=gridBx+((gridnmb-1)*cellx);
            cy=gridBy-((gridnmb-2)*celly);
        case 19  
            cx=gridCx-(gridnmb*cellx);
            cy=gridCy+((gridnmb-3)*celly);
        case 20 
            cx=gridCx-((gridnmb-1)*cellx);
            cy=gridCy+((gridnmb-3)*celly);
        case 21 
            cx=gridCx-((gridnmb-2)*cellx);
            cy=gridCy+((gridnmb-3)*celly);
        case 22 
            cx=gridCx-(gridnmb*cellx);
            cy=gridCy+((gridnmb-2)*celly);
        case 23 
            cx=gridCx-((gridnmb-1)*cellx);
            cy=gridCy+((gridnmb-2)*celly);     
        case 24 
            cx=gridCx-((gridnmb-2)*cellx);
            cy=gridCy+((gridnmb-2)*celly);    
        case 25 
            cx=gridCx-(gridnmb*cellx);
            cy=gridCy+((gridnmb-1)*celly);
        case 26 
            cx=gridCx-((gridnmb-1)*cellx);
            cy=gridCy+((gridnmb-1)*celly);        
        case 27 
            cx=gridCx-((gridnmb-2)*cellx);
            cy=gridCy+((gridnmb-1)*celly);
        case 28  
            cx=gridDx+((gridnmb-3)*cellx);
            cy=gridDy+((gridnmb-3)*celly);
        case 29 
            cx=gridDx+((gridnmb-2)*cellx);
            cy=gridDy+((gridnmb-3)*celly);
        case 30 
            cx=gridDx+((gridnmb-1)*cellx);
            cy=gridDy+((gridnmb-3)*celly);
        case 31 
            cx=gridDx+((gridnmb-3)*cellx);
            cy=gridDy+((gridnmb-2)*celly);
        case 32 
            cx=gridDx+((gridnmb-2)*cellx);
            cy=gridDy+((gridnmb-2)*celly);     
        case 33 
            cx=gridDx+((gridnmb-1)*cellx);
            cy=gridDy+((gridnmb-2)*celly);    
        case 34 
            cx=gridDx+((gridnmb-3)*cellx);
            cy=gridDy+((gridnmb-1)*celly);
        case 35 
            cx=gridDx+((gridnmb-2)*cellx);
            cy=gridDy+((gridnmb-1)*celly);        
        case 36 
            cx=gridDx+((gridnmb-1)*cellx);
            cy=gridDy+((gridnmb-1)*celly);
    end;
