import requests
import pandas as pd
from td.client import TDClient
import yfinance as yf
import schedule

import os
import datetime

CONSUMER_KEY = os.environ['TDA_CONSUMER_KEY']
REDIRECT_URI = os.environ['TDA_REDIRECT_URI']
TD_ACCOUNT = os.environ['TDA_ACCOUNT_ID']
SP500_ETF = 'VOO'

BOT_TOKEN = os.environ['TG_BOT_TOKEN']
CHANNEL_ID = os.environ['TG_CHAT_ID']

def connect_to_TDA():
    TDSession = TDClient(
        client_id=CONSUMER_KEY,
        redirect_uri=REDIRECT_URI,
        credentials_path='tda_key.json'
    )

    TDSession.login()
    return TDSession

def get_positions(TDSession):
    positions = TDSession.get_accounts(account=TD_ACCOUNT, fields=['positions'])
    df_positions = pd.DataFrame(positions['securitiesAccount']['positions'])
    df_portfolio = (
        pd.concat([df_positions.drop('instrument', axis=1), df_positions['instrument'].apply(pd.Series)], axis=1)
        .loc[lambda x: x['assetType'] == 'EQUITY']
        [['symbol', 'marketValue']]
    )

    return df_portfolio

def get_transactions(TDSession, df_portfolio):
    transactions = TDSession.get_transactions(account=TD_ACCOUNT, transaction_type='BUY_ONLY')
    df_buys = (
        pd.json_normalize(transactions)
        .loc[lambda x: x['transactionItem.instrument.symbol'].isin(df_portfolio.symbol)]
        .rename(columns={
            'netAmount': 'amount',
            'transactionDate': 'dt'
        })
        [['dt', 'amount']]
        .assign(
            dt = lambda x: pd.to_datetime(x['dt']).dt.date,
            amount = lambda x: -x['amount']
        )
        .groupby(['dt'], as_index=False)
        ['amount']
        .sum()
    )

    return df_buys

def get_sp500_history(df_buys):
    start = df_buys['dt'].min()
    end = df_buys['dt'].max() + datetime.timedelta(days=1) # Include the last day

    df_sp500 = (
        yf.download(SP500_ETF, start=start, end=end, progress=False)
        .reset_index()
        .rename(columns={
            'Date': 'dt',
            'Close': 'sp500_price'
        })
        [['dt', 'sp500_price']]
        .assign(
            dt = lambda x: pd.to_datetime(x['dt']).dt.date
        )
    )

    return df_sp500

def generate_metrics(df_buys, df_sp500, df_portfolio):
    df_buys_w_sp500 = (
        df_buys
        .merge(df_sp500, how='left', on='dt')
        .assign(
            sp500_cnt = lambda x: x['amount'] / x['sp500_price']
        )
    )

    sp500_current = yf.Ticker(SP500_ETF).history(period='1d')['Close'][0]

    open_balance = df_buys_w_sp500.amount.sum()
    sp500_market_value = df_buys_w_sp500.sp500_cnt.sum() * sp500_current
    portfolio_market_value = df_portfolio.marketValue.sum()

    return {
        'open_balance': open_balance,
        'sp500_market_value': sp500_market_value,
        'portfolio_market_value': portfolio_market_value,
    }

def generate_message(metrics):
    profit = metrics['portfolio_market_value'] - metrics['open_balance']
    profit_growth = profit / metrics['open_balance']
    sp500_growth = (metrics['sp500_market_value'] - metrics['open_balance']) / metrics['open_balance']
    return f"""
Balance: *${metrics['portfolio_market_value']:,.0f}*

Profit: {"🍏" if profit > 0 else "🍎"} *${profit:,.0f} ({profit_growth:,.2%})*
S&P 500: {sp500_growth:,.2%}
"""

def send_text(bot_message):

    url = f'https://api.telegram.org/bot{BOT_TOKEN}/sendMessage'
    params = {
        'chat_id': CHANNEL_ID,
        'text': bot_message,
        'parse_mode': 'Markdown'
    }

    response = requests.get(url, params=params)
    print(f"OK: {response.json()['ok']}")
    return response.json()

def send_notification():

    TDSession = connect_to_TDA()
    df_portfolio = get_positions(TDSession)
    df_buys = get_transactions(TDSession, df_portfolio)
    df_sp500 = get_sp500_history(df_buys)
    metrics = generate_metrics(df_buys, df_sp500, df_portfolio)
    message = generate_message(metrics)

    return send_text(message)

schedule.every().day.at('00:03').do(send_notification)

while True:
    schedule.run_pending()
