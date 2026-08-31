function export_figure_pair(fig, figureRoot, name)
%EXPORT_FIGURE_PAIR Export matching high-resolution PNG and vector PDF.
if ~exist(figureRoot, 'dir'), mkdir(figureRoot); end
style_figure(fig);
pngPath = fullfile(figureRoot, [name '.png']);
pdfPath = fullfile(figureRoot, [name '.pdf']);
exportgraphics(fig, pngPath, 'Resolution', 180);
exportgraphics(fig, pdfPath, 'ContentType', 'vector');
close(fig);
end
