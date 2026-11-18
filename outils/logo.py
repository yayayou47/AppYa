#!/usr/bin/env python3
"""Logo Daftar (monogramme D) : produit les SVG et, avec Chrome sans interface, toutes les images PNG.

Dessin (unités 0–64, centre 32,32) :
  - D doré : fût de x 12 à 25, panse de rayon 22 (y 10 → 54) ; creux : rayon 12 (y 20 → 44).
  - deux barres du $, dorées elles aussi (demande du 2026-11-18), au MILIEU de la lettre : elles la traversent sans
    apparaître dans le creux ; on n'en voit que les bouts arrondis qui dépassent d'environ 5 en haut et en bas.
  - livre ouvert crème dans le creux, chaque page portant des chiffres (style afficheur) en bleu.
Le tout est mis à l'échelle s autour du centre selon l'usage (icône arrondie, icône masquable, avant-plan Android…).

Usage : python3 outils/logo.py    (réécrit app/daftar.svg, assets/*.svg, les PNG de app/ et assets/)
"""
import os, subprocess, tempfile, shutil

BLEU, OR, CREME = '#1f4e79', '#f2b93f', '#f5f3ee'
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# chiffres à 7 segments dans une case 1,5 × 2,6 (a haut, b haut droit, c bas droit, d bas, e bas gauche, f haut gauche, g milieu)
SEG = {'a': ((0, 0), (1, 0)), 'b': ((1, 0), (1, .5)), 'c': ((1, .5), (1, 1)), 'd': ((0, 1), (1, 1)),
       'e': ((0, .5), (0, 1)), 'f': ((0, 0), (0, .5)), 'g': ((0, .5), (1, .5))}
CHIFFRES = {'0': 'abcdef', '1': 'bc', '2': 'abged', '3': 'abgcd', '4': 'fgbc', '5': 'afgcd', '6': 'afgedc',
            '7': 'abc', '8': 'abcdefg', '9': 'abcdfg'}


def chiffres(texte, x, y, l=1.5, h=2.6, pas=2.2):
    d = []
    for i, ch in enumerate(texte):
        x0 = x + i * pas
        for s in CHIFFRES[ch]:
            (a, b), (c, e) = SEG[s]
            d.append(f'M{x0 + a * l:.2f} {y + b * h:.2f}L{x0 + c * l:.2f} {y + e * h:.2f}')
    return ''.join(d)


def monogramme():
    """Le D, ses barres et le livre, en unités 0–64 (sans fond)."""
    d = ('M12 10h18a22 22 0 0 1 0 44H12z'          # contour du D
         'M25 20h5a12 12 0 0 1 0 24h-5z')           # creux
    # barres au milieu de la lettre (x 28–31 et 33–36, centre 32) : elles « traversent » le D de haut en bas, mais seuls
    # leurs bouts, au-dessus et au-dessous, se voient ; dans le creux elles sont interrompues (deux morceaux par barre,
    # qui s'arrêtent dans l'épaisseur dorée du haut et du bas).
    barres = ''.join(f'<rect x="{x}" y="{y}" width="3" height="10" rx="1.5"/>' for x in (28, 33) for y in (5, 49))
    pages = ('M27.4 26c2.1-1.2 4.3-1.2 5.9 0v12.2c-1.6-1.05-3.8-1.05-5.9 0z'
             'M33.3 26c1.6-1.2 3.8-1.2 5.9 0v12.2c-2.1-1.05-4.3-1.05-5.9 0z')
    num = (chiffres('12', 28.5, 28.2) + chiffres('34', 28.5, 32.6) +
           chiffres('56', 34.4, 28.2) + chiffres('78', 34.4, 32.6))
    return (f'<path fill-rule="evenodd" fill="{OR}" d="{d}"/>'
            f'<g fill="{OR}">{barres}</g>'
            f'<path fill="{CREME}" d="{pages}"/>'
            f'<path fill="none" stroke="{BLEU}" stroke-width=".42" stroke-linecap="round" stroke-linejoin="round" d="{num}"/>')


def svg(s=1.0, fond='arrondi', taille=None):
    """fond : 'arrondi' (carré à coins ronds), 'plein' (carré bleu), None (transparent)."""
    t = '' if s == 1 else f' transform="translate(32 32) scale({s}) translate(-32 -32)"'
    f = {'arrondi': f'<rect width="64" height="64" rx="14" fill="{BLEU}"/>', 'plein': f'<rect width="64" height="64" fill="{BLEU}"/>', None: ''}[fond]
    dim = f' width="{taille}" height="{taille}"' if taille else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"{dim}>{f}<g{t}>{monogramme()}</g></svg>'


def png(contenu_svg, chemin, taille):
    """Rendu fidèle par Chrome sans interface (fond transparent conservé)."""
    with tempfile.TemporaryDirectory() as tmp:
        page = os.path.join(tmp, 'p.html')
        open(page, 'w').write(f'<!doctype html><html><body style="margin:0;background:transparent">'
                              f'{contenu_svg.replace("<svg ", f"<svg style=\"display:block\" ", 1)}</body></html>')
        subprocess.run(['google-chrome', '--headless=new', '--disable-gpu', '--hide-scrollbars', f'--user-data-dir={tmp}/profil',
                        '--default-background-color=00000000', f'--window-size={taille},{taille}',
                        f'--screenshot={chemin}', f'file://{page}'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    ecrire = lambda rel, txt: open(os.path.join(RACINE, rel), 'w').write(txt + '\n')
    # icône arrondie (favicon, logo) : le D et ses barres occupent 84 % de la hauteur
    ecrire('app/daftar.svg', svg())
    ecrire('assets/logo-daftar.svg', svg())
    # monogramme seul, cadré au plus près (barres comprises)
    ecrire('assets/monogramme-d.svg', svg(fond=None).replace('viewBox="0 0 64 64"', 'viewBox="11 4 42 56"'))
    a = lambda rel: os.path.join(RACINE, rel)
    png(svg(taille=512), a('app/daftar-512.png'), 512)
    png(svg(taille=192), a('app/daftar-192.png'), 192)
    # masquable (le système découpe un cercle ou une forme à 80 % de diamètre « sûr ») : échelle 0,78 (coins du D dans le cercle sûr)
    png(svg(.78, 'plein', 512), a('app/daftar-512-masque.png'), 512)
    # APK (outil capacitor-assets) : icône classique + icône adaptative (avant-plan transparent, arrière-plan bleu).
    # Android ne montre que les 2/3 centraux de l'avant-plan : échelle 0,58 → le D et ses barres remplissent ≈ 73 % de l'icône visible, coins dans le cercle.
    png(svg(.85, 'plein', 1024), a('assets/icon-only.png'), 1024)
    png(svg(.58, None, 1024), a('assets/icon-foreground.png'), 1024)
    png(f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024"><rect width="1024" height="1024" fill="{BLEU}"/></svg>',
        a('assets/icon-background.png'), 1024)
    # écran de démarrage : logo au centre, petit, sur fond bleu
    for nom in ('splash.png', 'splash-dark.png'):
        png(svg(.3, 'plein', 2732), a('assets/' + nom), 2732)
    print('Logo régénéré.')


if __name__ == '__main__':
    main()
