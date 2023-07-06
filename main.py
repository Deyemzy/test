def create_alert_condition(policy_id, monitor_name, monitor_id, headers):    
    print("Policy ID:", policy_id)    
    alert_synthetic_url = 'https://api.newrelic.com/v2/alerts_synthetics_conditions/policies/{}.json'.format(policy_id)    
    alert_data = {    
        "synthetics_condition": {        
            "name": "{}".format(monitor_name),        
            "monitor_id": "{}".format(monitor_id),        
            "enabled": "true"        
        }    
    }    
    alert_endpoint_object = json.dumps(alert_data, indent = 4)    
    response = requests.post(alert_synthetic_url, headers=headers, data=alert_endpoint_object)
    print("Request URL:", alert_synthetic_url)    
    print("Request Body:", alert_endpoint_object)    
    print("Response Status Code: ", response.status_code)    
    print("Response Content:", response.content.decode('utf-8'))

    if response.status_code in [200, 201]:        
        resp = json.loads(response.content.decode('utf-8'))        
        try:            
            alert_id = resp['synthetics_condition']['id']            
            print("Alert condition '{}' created with ID: {}".format(resp['synthetics_condition']['name'], alert_id))            
            return alert_id        
        except KeyError:            
            print("Key 'synthetics_condition' not found in the response.")            
            return None    
    else:        
        print("Error occurred. Status Code: ", response.status_code)        
        return None



The script was returning an error for 201 status code, so I have modified it to handle 201 as a successful status code. The 201 status code means "Created" in HTTP terms, which indicates that your request to create an alert condition was successful. 
