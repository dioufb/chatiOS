/*
Copyright 2017 - 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
    http://aws.amazon.com/apache2.0/
or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
*/

/* Amplify Params - DO NOT EDIT
You can access the following resource attributes as environment variables from your Lambda function
var environment = process.env.ENV
var region = process.env.REGION

Amplify Params - DO NOT EDIT */

const AWS = require('aws-sdk')
var awsServerlessExpressMiddleware = require('aws-serverless-express/middleware')
var bodyParser = require('body-parser')
var express = require('express')

AWS.config.update({ region: process.env.TABLE_REGION });

const connect = new AWS.Connect();
var connectparticipant = new AWS.ConnectParticipant();
const dynamodb = new AWS.DynamoDB.DocumentClient();

let tableName = "connectChatiOSDB";
if(process.env.ENV && process.env.ENV !== "NONE") {
  tableName = tableName + '-' + process.env.ENV;
}

const userIdPresent = false; // TODO: update in case is required to use that definition
const partitionKeyName = "contactId";
const partitionKeyType = "S";
const sortKeyName = "";
const sortKeyType = "";
const hasSortKey = sortKeyName !== "";
const path = "/startChat";
const UNAUTH = 'UNAUTH';
const hashKeyPath = '/:' + partitionKeyName;
const sortKeyPath = hasSortKey ? '/:' + sortKeyName : '';
// declare a new express app
var app = express()
app.use(bodyParser.json())
app.use(awsServerlessExpressMiddleware.eventContext())

// Enable CORS for all methods
app.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*")
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept")
  next()
});

// convert url string param to expected Type
const convertUrlType = (param, type) => {
  switch(type) {
    case "N":
      return Number.parseInt(param);
    default:
      return param;
  }
}

/********************************
 * HTTP Get method for list objects *
 ********************************/

app.get(path + hashKeyPath, function(req, res) {
  var condition = {}
  condition[partitionKeyName] = {
    ComparisonOperator: 'EQ'
  }

  if (userIdPresent && req.apiGateway) {
    condition[partitionKeyName]['AttributeValueList'] = [req.apiGateway.event.requestContext.identity.cognitoIdentityId || UNAUTH ];
  } else {
    try {
      condition[partitionKeyName]['AttributeValueList'] = [ convertUrlType(req.params[partitionKeyName], partitionKeyType) ];
    } catch(err) {
      res.statusCode = 500;
      res.json({error: 'Wrong column type ' + err});
    }
  }

  let queryParams = {
    TableName: tableName,
    KeyConditions: condition
  }

  dynamodb.query(queryParams, (err, data) => {
    if (err) {
      res.statusCode = 500;
      res.json({error: 'Could not load items: ' + err});
    } else {
      res.json(data.Items);
    }
  });
});

/*****************************************
 * HTTP Get method for get single object *
 *****************************************/

app.get(path + '/object' + hashKeyPath + sortKeyPath, function(req, res) {
  var params = {};
  if (userIdPresent && req.apiGateway) {
    params[partitionKeyName] = req.apiGateway.event.requestContext.identity.cognitoIdentityId || UNAUTH;
  } else {
    params[partitionKeyName] = req.params[partitionKeyName];
    try {
      params[partitionKeyName] = convertUrlType(req.params[partitionKeyName], partitionKeyType);
    } catch(err) {
      res.statusCode = 500;
      res.json({error: 'Wrong column type ' + err});
    }
  }
  if (hasSortKey) {
    try {
      params[sortKeyName] = convertUrlType(req.params[sortKeyName], sortKeyType);
    } catch(err) {
      res.statusCode = 500;
      res.json({error: 'Wrong column type ' + err});
    }
  }

  let getItemParams = {
    TableName: tableName,
    Key: params
  }

  dynamodb.get(getItemParams,(err, data) => {
    if(err) {
      res.statusCode = 500;
      res.json({error: 'Could not load items: ' + err.message});
    } else {
      if (data.Item) {
        res.json(data.Item);
      } else {
        res.json(data) ;
      }
    }
  });
});


/************************************
* HTTP put method for insert object *
*************************************/

app.put(path, function(req, res) {

  console.log('||||||||||||||=>',req.body);

  if (userIdPresent) {
    req.body['userId'] = req.apiGateway.event.requestContext.identity.cognitoIdentityId || UNAUTH;
  }


  startChatContact(req.body.request).then((startChatResult) => {
    let response= buildSuccessfulResponse(startChatResult);
    res.json({success: 'put call succeed!', url: req.url, data: response})

    // console.log(response)
    // let putItemParams = {
    //   TableName: tableName,
    //   Item: response
    // }    
    // dynamodb.put(putItemParams, (err, data) => {
    //   if(err) {
    //     res.statusCode = 500;
    //     res.json({error: err, url: req.url, body: req.body});
    //   } else{
    //     res.json({success: 'put call succeed!', url: req.url, data: response})
    //   }
    // });    
  }).catch((err) => {
      console.log("caught error " + err);
      res.json(buildResponseFailed(err));
  });


});

function startChatContact(body) {
  
  var contactFlowId = "6b3a6129-4882-47b9-b843-c218150e2ce5";
  if(body.hasOwnProperty('ContactFlowId')){
      contactFlowId = body["ContactFlowId"];
  }
  console.log("CF ID: " + contactFlowId);
  
  var instanceId = "5e6085d9-44ac-4706-bbf0-78798a4e92ec";
  if(body.hasOwnProperty('InstanceId')){
      instanceId = body["InstanceId"];
  }
  console.log("Instance ID: " + instanceId);

  return new Promise(function (resolve, reject) {
      
      let payload = JSON.parse(body)
      var startChat = {
          "InstanceId": instanceId == "" ? process.env.INSTANCE_ID : instanceId,
          "ContactFlowId": contactFlowId == "" ? process.env.CONTACT_FLOW_ID : contactFlowId,
          "Attributes": {
              "customerName": payload.DisplayName
          },
          "ParticipantDetails": {
              "DisplayName": payload.DisplayName
          }
      };
      console.log('Starting Chat with =>>>>>> ',startChat)
      connect.startChatContact(startChat, function(err, data) {
          if (err) {
              console.log("Error starting the chat.");
              console.log(err, err.stack);
              reject(err);
          } else {
              console.log("Start chat succeeded with the response: " + JSON.stringify(data));
              const copiedData = Object.assign({}, data);
              delete copiedData.ParticipantToken;
              
              var updateContactAttributeParams = {
                Attributes: copiedData,
                InitialContactId: copiedData.ContactId,
                InstanceId: instanceId == "" ? process.env.INSTANCE_ID : instanceId
              };
              connect.updateContactAttributes(updateContactAttributeParams, function(err, dt) {
                if (err) { 
                    console.log(err, err.stack); // an error occurred
                    reject(err);
                } else    {
                    console.log('Update Result',dt);           // successful response
                    var params = {
                      ParticipantToken: data.ParticipantToken, /* required */
                      Type: ["WEBSOCKET","CONNECTION_CREDENTIALS"]
                    };
                    connectparticipant.createParticipantConnection(params, function(err, dt2) {
                      if (err) { 
                        console.log(err, err.stack); // an error occurred
                        reject(err)
                      } else  {
                        dt2.chatDetails = data;
                        console.log('Participant Output',dt2);           // successful response
                        resolve(dt2)
                      } 
                    });                    
                    
                }
              });


              //resolve(data);
          }
      });

  });
}

function buildSuccessfulResponse(result) {
  const response = {
      statusCode: 200,
      headers: {
          "Access-Control-Allow-Origin": "*",
          'Content-Type': 'application/json',
          'Access-Control-Allow-Credentials' : true,
          'Access-Control-Allow-Headers':'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
      },
      body: JSON.stringify( result)
  };
  console.log("RESPONSE" + JSON.stringify(response));
  return response;
}

function buildResponseFailed(err) {
  const response = {
      statusCode: 500,
      headers: {
          "Access-Control-Allow-Origin": "*",
          'Content-Type': 'application/json',
          'Access-Control-Allow-Credentials' : true,
          'Access-Control-Allow-Headers':'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
      },
      body: JSON.stringify({
          data: {
              "Error": err
          }
      })
  };
  return response;
}

/************************************
* HTTP post method for insert object *
*************************************/

app.post(path, function(req, res) {

  if (userIdPresent) {
    req.body['userId'] = req.apiGateway.event.requestContext.identity.cognitoIdentityId || UNAUTH;
  }

  let putItemParams = {
    TableName: tableName,
    Item: req.body
  }
  dynamodb.put(putItemParams, (err, data) => {
    if(err) {
      res.statusCode = 500;
      res.json({error: err, url: req.url, body: req.body});
    } else{
      res.json({success: 'post call succeed!', url: req.url, data: data})
    }
  });
});

/**************************************
* HTTP remove method to delete object *
***************************************/

app.delete(path + '/object' + hashKeyPath + sortKeyPath, function(req, res) {
  var params = {};
  if (userIdPresent && req.apiGateway) {
    params[partitionKeyName] = req.apiGateway.event.requestContext.identity.cognitoIdentityId || UNAUTH;
  } else {
    params[partitionKeyName] = req.params[partitionKeyName];
     try {
      params[partitionKeyName] = convertUrlType(req.params[partitionKeyName], partitionKeyType);
    } catch(err) {
      res.statusCode = 500;
      res.json({error: 'Wrong column type ' + err});
    }
  }
  if (hasSortKey) {
    try {
      params[sortKeyName] = convertUrlType(req.params[sortKeyName], sortKeyType);
    } catch(err) {
      res.statusCode = 500;
      res.json({error: 'Wrong column type ' + err});
    }
  }

  let removeItemParams = {
    TableName: tableName,
    Key: params
  }
  dynamodb.delete(removeItemParams, (err, data)=> {
    if(err) {
      res.statusCode = 500;
      res.json({error: err, url: req.url});
    } else {
      res.json({url: req.url, data: data});
    }
  });
});
app.listen(3000, function() {
    console.log("App started")
});

// Export the app object. When executing the application local this does nothing. However,
// to port it to AWS Lambda we will create a wrapper around that will load the app from
// this file
module.exports = app
