## Create environment
```bash
python3 -m venv venv
source ./venv/bin/activate

# install requirements package
pip install -r requirements.txt
```
## Run server
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```