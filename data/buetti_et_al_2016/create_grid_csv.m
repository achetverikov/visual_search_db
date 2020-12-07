fileID=fopen('buetti_grid.csv','w+')
fprintf(fileID,'loc_id,posx,posy,posx_deg,posy_deg\n')

pix_to_angle = 1.5/100; % the  paper says "the average spacing between elements was 1.5 degrees of visual angle"
for (x = 1:36) 
    [posx, posy] = grid(x);
    fprintf(fileID,'%d,%d,%d,%d,%d\n',x,posx,posy,posx*pix_to_angle,posy*pix_to_angle);
end
fclose(fileID)
