---
layout: post
title:  "How to analyze investment portfolio using Python, Part 2: Telegram Notifications"
date: 2021-05-26 11:06:00 +0600
categories: data analysis
permalink: /investment-portfolio-part2/
---

# General Idea
In the [previous part](https://bjolko.github.io/investment-portfolio-part1/), we used TD Ameritrade API and Yahoo Finance to see the current portfolio balance and profit and compare it to S&P 500 dynamics. Now I want to set up daily notifications with these statistics, so I don't have to run the Jupyter Notebook manually. Today we are going to build a Telegram Bot running on the Heroku platform. 🚀

# Setting up Telegram Bot and Channel
First, let's create a new Telegram Bot using `@BotFather`, just write the `/newbot` command in the chat and follow the instructions, more in the official [documentation](https://core.telegram.org/bots). In the end, `@BotFather` will send you an API token. We will use it later, so save it.

Next, we need a private channel for the notifications and get its ID. Once you added a channel, go to [Telegram Web](https://web.telegram.org/), open the channel chat and copy the number between `c` and `_` from the URL, as in an example
```
https://web.telegram.org/#/im?p=c<CHAT ID>_9687443952281738857
```
Then add `-100` at the beginning of your number (`-100<CHAT ID>`), and that's your ID! For public channels, use `@channelusername`.

# Python Script
We start with setting up libraries and config variables
```python
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
```
For Ameritrade data I used the script from [the first part](https://bjolko.github.io/investment-portfolio-part1/) and wrapped it to functions to increase code readability.
```python
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
```
Then we need to generate a markdown message, that we are going to send ✉️. I am sending green apple for positive profit, and a red one for negative :)
```python
def generate_message(metrics):
    profit = metrics['portfolio_market_value'] - metrics['open_balance']
    profit_growth = profit / metrics['open_balance']
    sp500_growth = (metrics['sp500_market_value'] - metrics['open_balance']) / metrics['open_balance']
    return f"""
Balance: *${metrics['portfolio_market_value']:,.0f}*

Profit: {"🍏" if profit > 0 else "🍎"} *${profit:,.0f} ({profit_growth:,.2%})*
S&P 500: {sp500_growth:,.2%}
"""
```
We will use `sendMessage` endpoint in Telegram Bot API to send a message
```python
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
```
Here is the final function or job
```python
def send_notification():

    TDSession = connect_to_TDA()
    df_portfolio = get_positions(TDSession)
    df_buys = get_transactions(TDSession, df_portfolio)
    df_sp500 = get_sp500_history(df_buys)
    metrics = generate_metrics(df_buys, df_sp500, df_portfolio)
    message = generate_message(metrics)

    return send_text(message)
```
Finally, let's schedule it using [schedule](https://pypi.org/project/schedule/) library
```python
# Server Timezone. Heroku default is UTC
schedule.every().day.at('00:00').do(send_notification)

# Checks if it's time to run
while True:
    schedule.run_pending()
```
And that's it! Here is the [full code](https://github.com/bjolko/bjolko.github.io/blob/master/docs/assets/posts/investment-portfolio-part2/send_message.py).
# Running an app on Heroku
## App folder
1. Save your script as **.py** file
2. Save **tda_key.json** file that contains Ameritrade API access and refresh tokens
3. Create **requirements.txt** file with needed libraries and their versions
4. Create **runtime.txt** and specify the Python version that you are using. For example, my file contains one line with
```
python-3.7.10
```
5. Create **Procfile** without file extension, open it with any text editor  and put
```
worker: python3 <YOUR SCRIPT NAME>.py
```

It will tell Heroku what to run and how.
## Deployment
Now we are ready to deploy! You can use both Heroku UI and the command line. I will go through the CLI example.

1. Create a Heroku account. It's free for personal use :)
2. Install [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)
3. Install [Git](https://git-scm.com/downloads)
4. To authorize, write in your command line
```
$ heroku login
```
5. Create an app
```
$ heroku create <YOUR-APP-NAME>
```
6. Add [config variables](https://devcenter.heroku.com/articles/config-vars)
```
$ heroku config:set CONSUMER_KEY=<YOUR TDA CONSUMER KEY>
```
7. Navigate to your App Folder and initialize a git repository
```
$ cd App-Folder/
$ git init
$ heroku git:remote -a <YOUR-APP-NAME>
```
8. Deploy your app
```
$ git add .
$ git commit -am "make it better"
$ git push heroku master
```
You can check logs from your app by this link `https://dashboard.heroku.com/apps/<YOUR-APP-NAME>/logs`.

Yay, that's it! Now you have a daily notifications about your investment portfolio :)
