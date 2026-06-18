"""
EDA des trades du Cerveau Adaptatif.
Lit le CSV log MQL5, joint open/close, extrait features, calcule stats par segment.
Stdlib uniquement (pas de pandas).
"""
import csv
import sys
from collections import defaultdict, Counter
from datetime import datetime
import statistics


def parse_log(path):
    """Parse the EA's CSV log. Returns list of trade dicts (open + close joined)."""
    opens = []   # stack of open events not yet closed
    trades = []  # final list of completed trades

    with open(path, encoding='utf-8', errors='replace') as f:
        reader = csv.DictReader(f)
        for row in reader:
            signal = row.get('Signal', '')
            profit = row.get('Profit', '')
            if signal.endswith('_OUVERTURE'):
                opens.append(row)
            elif profit not in ('', 'OUVERT'):
                # Close event — match with the most recent open of same direction
                # MQL5 ne donne pas le ticket dans ce log, on fait FIFO
                if opens:
                    op = opens.pop(0)
                    try:
                        profit_val = float(profit.replace(' ', '').replace(',', '.'))
                    except ValueError:
                        continue
                    trades.append({
                        'open_date':    op['Date'],
                        'open_time':    op['Heure'],
                        'close_date':   row['Date'],
                        'close_time':   row['Heure'],
                        'signal':       op['Signal'].replace('_OUVERTURE', ''),
                        'adn_mi_psy':   op['ADN_Miroir_Psy'],
                        'type':         op['Type'],
                        'direction':    op['Direction'],
                        'entry':        float(op['Entry']),
                        'sl_str':       op['NiveauSL'],
                        'tp_str':       op['NiveauTP'],
                        'lots_str':     op['Lots'],
                        'balance_open': float(op['Balance']),
                        'profit':       profit_val,
                        'raison_close': row.get('RaisonSL', '') or row.get('RaisonTP', ''),
                    })
    return trades


def derive_features(trades):
    """Add derived features to each trade dict."""
    for t in trades:
        # Parse SL / TP / Lots
        try:
            t['sl']  = float(t['sl_str'].split('=')[1])
            t['tp']  = float(t['tp_str'].split('=')[1])
            t['lots'] = float(t['lots_str'].split('=')[1])
        except (ValueError, IndexError):
            t['sl'] = t['tp'] = t['lots'] = float('nan')

        # Parse ADN | Miroir | Psy
        parts = t['adn_mi_psy'].split('|')
        t['adn']    = parts[0] if len(parts) > 0 else 'UNK'
        t['miroir'] = parts[1] if len(parts) > 1 else 'UNK'
        t['psy']    = parts[2] if len(parts) > 2 else 'UNK'

        # Simplifier le nom du signal
        sig = t['signal']
        if 'TENDANCE' in sig:
            t['signal_class'] = 'TENDANCE'
        elif 'PULLBACK' in sig:
            t['signal_class'] = 'PULLBACK'
        elif 'OVERRIDE' in sig:
            t['signal_class'] = 'SELL_OVERRIDE'
        else:
            t['signal_class'] = 'OTHER'

        # Distance Entry → SL (en $) et RR cible
        if not (t['sl'] != t['sl']):  # not nan
            t['sl_dist']    = abs(t['entry'] - t['sl'])
            t['tp_dist']    = abs(t['tp']    - t['entry'])
            t['rr_target']  = t['tp_dist'] / t['sl_dist'] if t['sl_dist'] > 0 else 0
            t['sl_dist_pct'] = t['sl_dist'] / t['entry'] * 100

        # Date / heure parsée
        try:
            dt = datetime.strptime(f"{t['open_date']} {t['open_time']}", "%Y.%m.%d %H:%M")
            t['hour']        = dt.hour
            t['dow']         = dt.weekday()    # 0=Mon
            t['month']       = dt.month
            t['session']     = (
                'LONDON' if 7 <= dt.hour <= 13 else
                'NY'     if 14 <= dt.hour <= 21 else
                'ASIA'
            )
        except ValueError:
            t['hour'] = t['dow'] = t['month'] = -1
            t['session'] = 'UNK'

        # Win / loss
        t['win']         = 1 if t['profit'] > 0 else (0 if t['profit'] < 0 else None)
        t['profit_pct']  = t['profit'] / t['balance_open'] * 100 if t['balance_open'] else 0


def segment_stats(trades, key_fn, name):
    """Compute WR / avg PnL / count / PF for each segment."""
    print(f'\n========== STATS PAR {name} ==========')
    groups = defaultdict(list)
    for t in trades:
        if t['win'] is None:
            continue
        groups[key_fn(t)].append(t)

    rows = []
    for k, ts in groups.items():
        wins  = [t for t in ts if t['win'] == 1]
        losses = [t for t in ts if t['win'] == 0]
        gross_win  = sum(t['profit'] for t in wins)
        gross_loss = sum(abs(t['profit']) for t in losses)
        pf = gross_win / gross_loss if gross_loss > 0 else float('inf')
        wr = len(wins) / len(ts) * 100 if ts else 0
        avg_pnl = statistics.mean(t['profit'] for t in ts) if ts else 0
        net = gross_win - gross_loss
        rows.append((k, len(ts), wr, avg_pnl, pf, net))

    rows.sort(key=lambda r: -r[5])  # sort by net profit desc
    print(f'{"Segment":<45} {"N":>4} {"WR%":>6} {"AvgPnL":>8} {"PF":>6} {"Net":>9}')
    print('-' * 85)
    for r in rows:
        pf_str = f'{r[4]:.2f}' if r[4] != float('inf') else 'inf'
        print(f'{str(r[0])[:43]:<45} {r[1]:>4} {r[2]:>5.1f}% {r[3]:>7.2f} {pf_str:>6} {r[5]:>8.2f}')


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else \
        r'C:\Users\User\Desktop\Nouveau dossier (3)\Fotso_Cerveau_log_v55.csv'

    trades = parse_log(path)
    derive_features(trades)

    # Filter complete trades (no NaN, has win/loss)
    complete = [t for t in trades if t['win'] is not None and t['sl'] == t['sl']]
    print(f'\n=== TOTAL TRADES PARSED ===')
    print(f'  Raw trades parsed       : {len(trades)}')
    print(f'  Complete (with features): {len(complete)}')
    if not complete:
        return

    wins  = [t for t in complete if t['win'] == 1]
    losses = [t for t in complete if t['win'] == 0]
    print(f'  Wins                    : {len(wins)} ({len(wins)/len(complete)*100:.1f}%)')
    print(f'  Losses                  : {len(losses)} ({len(losses)/len(complete)*100:.1f}%)')
    print(f'  Sum profit              : {sum(t["profit"] for t in complete):.2f}')
    print(f'  Avg profit/trade        : {sum(t["profit"] for t in complete)/len(complete):.2f}')

    # Segment analyses
    segment_stats(complete, lambda t: t['signal_class'],          'CLASSE SIGNAL')
    segment_stats(complete, lambda t: t['adn'],                    'PHASE ADN')
    segment_stats(complete, lambda t: t['miroir'],                 'MIROIR INSTITUTIONNEL')
    segment_stats(complete, lambda t: t['psy'],                    'EMPREINTE PSY')
    segment_stats(complete, lambda t: t['adn_mi_psy'],             'COMBO ADN|Mi|Psy')
    segment_stats(complete, lambda t: t['session'],                'SESSION')
    segment_stats(complete, lambda t: t['hour'],                   'HEURE OUVERTURE')
    segment_stats(complete, lambda t: t['dow'],                    'JOUR (0=Lun)')
    segment_stats(complete, lambda t: t['month'],                  'MOIS')

    # Bucket de RR cible
    def rr_bucket(t):
        rr = t.get('rr_target', 0)
        if rr < 1.5:  return '< 1.5'
        if rr < 2.0:  return '1.5-2.0'
        if rr < 3.0:  return '2.0-3.0'
        return '>= 3.0'
    segment_stats(complete, rr_bucket, 'RR CIBLE')

    # Bucket de SL dist %
    def sl_bucket(t):
        d = t.get('sl_dist_pct', 0)
        if d < 0.3:  return '< 0.3%'
        if d < 0.5:  return '0.3-0.5%'
        if d < 0.7:  return '0.5-0.7%'
        if d < 1.0:  return '0.7-1.0%'
        return '>= 1.0%'
    segment_stats(complete, sl_bucket, 'SL DISTANCE %')


if __name__ == '__main__':
    main()
