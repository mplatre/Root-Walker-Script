function imageout = cleanedges(imagein)

%Deletes the first 9 rows of pixels due to a black border being created
%from the smoothing of the image and extends it to the previous size
[h,w] = size(imagein);

row_pixel = imagein(10:end,:);
row_pixel(h,w) = 0;

row_pixel(:,1) = 1;
row_pixel(:,2) = 1;
row_pixel(:,3) = 1;
row_pixel(:,4) = 1;
row_pixel(:,5) = 1;
row_pixel(:,6) = 1;
row_pixel(:,7) = 1;
row_pixel(:,8) = 1;
row_pixel(:,9) = 1;
row_pixel(:,10) = 1;

row_pixel(:,w) = 1;
row_pixel(:,w-1) = 1;
row_pixel(:,w-2) = 1;
row_pixel(:,w-3) = 1;
row_pixel(:,w-4) = 1;
row_pixel(:,w-5) = 1;
row_pixel(:,w-6) = 1;
row_pixel(:,w-7) = 1;
row_pixel(:,w-8) = 1;
row_pixel(:,w-9) = 1;
row_pixel(:,w-10) = 1; %sets the edges to be white

row_pixel(:,1) = 0; %sets first column as black

imageout = row_pixel;

end

