function connectedout = con_midpoint(binaryin, selection)

preset = selection;
%Selects only the connected pixels with width greater than set value
if preset == 1
    root_constant = 8; %for 12 hour analysis with 2x objective
elseif preset == 2
    root_constant = 6; %for 20 min analysis with 4x objective 
end

row_pixel = binaryin;
[h,w] = size(row_pixel);
entire_image_black_pixels = {};
row_count = 0;

%Check to ensure proper size of datasets
if length(entire_image_black_pixels) ~= h
    for i = (length(entire_image_black_pixels)+1):h
        entire_image_black_pixels{i} = {};
    end
end

for i = 1:h %loop through each row of the pixels
    
    current_row = row_pixel(i,:); % 0 is black, 1 is white
    pixel_indices = find(~current_row); %finds indices of all black pixels
    split_after = find(diff(pixel_indices)-1); %find location of where to
    %split the previous vector to separate root pixels
    
    row_array = {};
    
    if isempty(split_after) %stops code if no more black pixels are found
        break
    end
    
    split = pixel_indices(1:split_after(1));
    row_array{1} = split;
    
    for j = 1:(length(split_after)-1)
        split = pixel_indices((split_after(j)+1):split_after(j+1));       
        row_array{j} = split;
    end
    
    %We check if elements haven't been included and add them if so
    if pixel_indices(split_after(length(split_after))) < max(pixel_indices)
        row_array{length(row_array)+1} = pixel_indices((max(split_after)+1):find(pixel_indices==max(pixel_indices)));
    end
    
    entire_image_black_pixels{i} = row_array;
    
    row_count = row_count + 1;
    
end

f_row = entire_image_black_pixels{1};
image_root_pos = {};

%Check again to ensure proper size of datasets
if length(entire_image_black_pixels) ~= h
    for i = (length(entire_image_black_pixels)+1):h
        entire_image_black_pixels{i} = {};
    end
end

%Before this point, there could be sets of connected black pixels that are
%not roots (background noise, etc.), so we use a set width to filter out
%anything that is too small to be a root.

for i = 1:h
    filter_row = entire_image_black_pixels{i}(cellfun('length', entire_image_black_pixels{i}) > root_constant);
    %After removing any smaller objects, we convert the list of connected
    %pixels to a single point in the middle of the set of connected pixels
    %in order to simplify processing and further analysis
    filter_row_mean = cellfun(@mean, filter_row);
    image_root_pos{i} = filter_row_mean;
end

connectedout = image_root_pos;

end