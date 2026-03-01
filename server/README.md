## For Linux
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


## For Window
# Create environment
```bash
python -m venv venv
.\venv\Scripts\Activate
```

# Install requirements
```bash
pip install -r requirements.txt
```

# Run server
```bash
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```