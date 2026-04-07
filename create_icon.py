#!/usr/bin/env python3
from PIL import Image, ImageDraw
import math
import os

def create_icon(size):
    """Crea un'icona moderna per Activity Tracker"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    margin = size // 10
    radius = center - margin
    
    # Sfondo con gradiente circolare (blu -> viola)
    for i in range(radius, 0, -1):
        ratio = i / radius
        r = int(59 + (139 - 59) * (1 - ratio))  # Da blu a viola
        g = int(130 + (92 - 130) * (1 - ratio))
        b = int(246 + (246 - 246) * (1 - ratio))
        draw.ellipse(
            [center - i, center - i, center + i, center + i],
            fill=(r, g, b, 255)
        )
    
    # Cerchio interno (sfondo scuro)
    inner_radius = int(radius * 0.75)
    draw.ellipse(
        [center - inner_radius, center - inner_radius, 
         center + inner_radius, center + inner_radius],
        fill=(30, 30, 40, 255)
    )
    
    # Disegna le tacche dell'orologio
    for i in range(12):
        angle = math.radians(i * 30 - 90)
        outer_r = inner_radius - size // 30
        inner_r = inner_radius - size // 15
        
        x1 = center + int(inner_r * math.cos(angle))
        y1 = center + int(inner_r * math.sin(angle))
        x2 = center + int(outer_r * math.cos(angle))
        y2 = center + int(outer_r * math.sin(angle))
        
        width = size // 40 if i % 3 == 0 else size // 60
        draw.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, 180), width=max(1, width))
    
    # Lancetta delle ore (corta, bianca)
    hour_angle = math.radians(60 - 90)  # Punta alle 2
    hour_length = inner_radius * 0.45
    hour_x = center + int(hour_length * math.cos(hour_angle))
    hour_y = center + int(hour_length * math.sin(hour_angle))
    draw.line([(center, center), (hour_x, hour_y)], 
              fill=(255, 255, 255, 255), width=max(2, size // 40))
    
    # Lancetta dei minuti (lunga, bianca)
    min_angle = math.radians(180 - 90)  # Punta alle 6
    min_length = inner_radius * 0.65
    min_x = center + int(min_length * math.cos(min_angle))
    min_y = center + int(min_length * math.sin(min_angle))
    draw.line([(center, center), (min_x, min_y)], 
              fill=(255, 255, 255, 255), width=max(1, size // 50))
    
    # Centro dell'orologio
    dot_radius = size // 25
    draw.ellipse(
        [center - dot_radius, center - dot_radius,
         center + dot_radius, center + dot_radius],
        fill=(59, 130, 246, 255)  # Blu
    )
    
    # Piccolo indicatore di attività (arco colorato in basso)
    arc_radius = inner_radius * 0.85
    arc_width = size // 20
    
    # Arco di progresso (verde/ciano)
    draw.arc(
        [center - arc_radius, center - arc_radius,
         center + arc_radius, center + arc_radius],
        start=120, end=240,
        fill=(52, 211, 153, 255),  # Verde
        width=max(2, arc_width)
    )
    
    return img

# Crea le icone in tutte le dimensioni necessarie
sizes = [16, 32, 64, 128, 256, 512, 1024]
iconset_path = "AppIcon.iconset"

os.makedirs(iconset_path, exist_ok=True)

for size in sizes:
    icon = create_icon(size)
    
    # Salva versione normale
    icon.save(f"{iconset_path}/icon_{size}x{size}.png")
    
    # Salva versione @2x (per retina)
    if size <= 512:
        icon_2x = create_icon(size * 2)
        icon_2x.save(f"{iconset_path}/icon_{size}x{size}@2x.png")

print("✅ Icone create!")


