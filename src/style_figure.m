function style_figure(fig)
%STYLE_FIGURE Force report-safe light styling independent of MATLAB theme.
set(fig,'Color','w','InvertHardcopy','off');
axesObjects = findall(fig,'Type','axes');
for k = 1:numel(axesObjects)
    if strcmp(axesObjects(k).Visible,'off')
        background = 'none';
    else
        background = 'w';
    end
    set(axesObjects(k),'Color',background,'XColor','k','YColor','k', ...
        'GridColor',[0.25 0.25 0.25],'MinorGridColor',[0.45 0.45 0.45]);
end
textObjects = findall(fig,'Type','text');
for k = 1:numel(textObjects)
    set(textObjects(k),'Color','k');
end
colorbars = findall(fig,'Type','colorbar');
for k = 1:numel(colorbars)
    set(colorbars(k),'Color','k');
end
legends = findall(fig,'Type','legend');
for k = 1:numel(legends)
    set(legends(k),'Color','w','TextColor','k','EdgeColor',[0.2 0.2 0.2]);
end
textboxes = findall(fig,'Type','textboxshape');
for k = 1:numel(textboxes)
    set(textboxes(k),'Color','k','EdgeColor',[0.2 0.2 0.2]);
end
arrows = findall(fig,'Type','arrowshape');
for k = 1:numel(arrows)
    set(arrows(k),'Color','k');
end
end
