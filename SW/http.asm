; HTTP
;
; This module implements EPNET's HTTP protocol
;
		module	http
;
;==============================================================================
;
; This file is part of the EPNET software
;
; Copyright (C) 2015  Bruce Tanner
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; If you do use or modify this file, either for its original purpose or for
; something new, I'd love to hear about it! I can be contacted by email at:
;
; brucetanner@btopenworld.com
;
;==============================================================================
;
; For reference, this is the format of an HTTP 1.0 message (from RFC 1945):
;
; 4.  HTTP Message
;
; 4.1  Message Types
;
;   HTTP messages consist of requests from client to server and responses
;   from server to client.
;
;       HTTP-message   = Simple-Request           ; HTTP/0.9 messages
;                      | Simple-Response
;                      | Full-Request             ; HTTP/1.0 messages
;                      | Full-Response
;
;   Full-Request and Full-Response use the generic message format of RFC
;   822 [7] for transferring entities. Both messages may include optional
;   header fields (also known as "headers") and an entity body. The
;   entity body is separated from the headers by a null line (i.e., a
;   line with nothing preceding the CRLF).
;
;       Full-Request   = Request-Line             ; Section 5.1
;                        *( General-Header        ; Section 4.3
;                         | Request-Header        ; Section 5.2
;                         | Entity-Header )       ; Section 7.1
;                        CRLF
;                        [ Entity-Body ]          ; Section 7.2
;
;       Full-Response  = Status-Line              ; Section 6.1
;                        *( General-Header        ; Section 4.3
;                         | Response-Header       ; Section 6.2
;                         | Entity-Header )       ; Section 7.1
;                        CRLF
;                        [ Entity-Body ]          ; Section 7.2
;
;   Simple-Request and Simple-Response do not allow the use of any header
;   information and are limited to a single request method (GET).
;
;       Simple-Request  = "GET" SP Request-URI CRLF
;
;       Simple-Response = [ Entity-Body ]
;
;   Use of the Simple-Request format is discouraged because it prevents
;   the server from identifying the media type of the returned entity.
;
; 4.2  Message Headers
;
;   HTTP header fields, which include General-Header (Section 4.3),
;   Request-Header (Section 5.2), Response-Header (Section 6.2), and
;   Entity-Header (Section 7.1) fields, follow the same generic format as
;   that given in Section 3.1 of RFC 822 [7]. Each header field consists
;   of a name followed immediately by a colon (":"), a single space (SP)
;   character, and the field value. Field names are case-insensitive.
;   Header fields can be extended over multiple lines by preceding each
;   extra line with at least one SP or HT, though this is not
;   recommended.
;
;       HTTP-header    = field-name ":" [ field-value ] CRLF
;
;       field-name     = token
;       field-value    = *( field-content | LWS )
;
;       field-content  = <the OCTETs making up the field-value
;                        and consisting of either *TEXT or combinations
;                        of token, tspecials, and quoted-string>
;
;   The order in which header fields are received is not significant.
;   However, it is "good practice" to send General-Header fields first,
;   followed by Request-Header or Response-Header fields prior to the
;   Entity-Header fields.
;
;   Multiple HTTP-header fields with the same field-name may be present
;   in a message if and only if the entire field-value for that header
;   field is defined as a comma-separated list [i.e., #(values)]. It must
;   be possible to combine the multiple header fields into one "field-
;   name: field-value" pair, without changing the semantics of the
;   message, by appending each subsequent field-value to the first, each
;   separated by a comma.
;
; 4.3  General Header Fields
;
;   There are a few header fields which have general applicability for
;   both request and response messages, but which do not apply to the
;   entity being transferred. These headers apply only to the message
;   being transmitted.
;
;       General-Header = Date                     ; Section 10.6
;                      | Pragma                   ; Section 10.12
;
;   General header field names can be extended reliably only in
;   combination with a change in the protocol version. However, new or
;   experimental header fields may be given the semantics of general
;   header fields if all parties in the communication recognize them to
;   be general header fields. Unrecognized header fields are treated as
;   Entity-Header fields.
;
; 5. Request
;
;   A request message from a client to a server includes, within the
;   first line of that message, the method to be applied to the resource,
;   the identifier of the resource, and the protocol version in use. For
;   backwards compatibility with the more limited HTTP/0.9 protocol,
;   there are two valid formats for an HTTP request:
;
;       Request        = Simple-Request | Full-Request
;
;       Simple-Request = "GET" SP Request-URI CRLF
;
;       Full-Request   = Request-Line             ; Section 5.1
;                        *( General-Header        ; Section 4.3
;                         | Request-Header        ; Section 5.2
;                         | Entity-Header )       ; Section 7.1
;                        CRLF
;                        [ Entity-Body ]          ; Section 7.2
;
;   If an HTTP/1.0 server receives a Simple-Request, it must respond with
;   an HTTP/0.9 Simple-Response. An HTTP/1.0 client capable of receiving
;   a Full-Response should never generate a Simple-Request.
;
; 5.1  Request-Line
;
;   The Request-Line begins with a method token, followed by the
;   Request-URI and the protocol version, and ending with CRLF. The
;   elements are separated by SP characters. No CR or LF are allowed
;   except in the final CRLF sequence.
;
;       Request-Line = Method SP Request-URI SP HTTP-Version CRLF
;
;   Note that the difference between a Simple-Request and the Request-
;   Line of a Full-Request is the presence of the HTTP-Version field and
;   the availability of methods other than GET.
;
; 5.1.1 Method
;
;   The Method token indicates the method to be performed on the resource
;   identified by the Request-URI. The method is case-sensitive.
;
;       Method         = "GET"                    ; Section 8.1
;                      | "HEAD"                   ; Section 8.2
;                      | "POST"                   ; Section 8.3
;                      | extension-method
;
;       extension-method = token
;
;   The list of methods acceptable by a specific resource can change
;   dynamically; the client is notified through the return code of the
;   response if a method is not allowed on a resource. Servers should
;   return the status code 501 (not implemented) if the method is
;   unrecognized or not implemented.
;
;   The methods commonly used by HTTP/1.0 applications are fully defined
;   in Section 8.
;
; 5.1.2 Request-URI
;
;   The Request-URI is a Uniform Resource Identifier (Section 3.2) and
;   identifies the resource upon which to apply the request.
;
;       Request-URI    = absoluteURI | abs_path
;
;   The two options for Request-URI are dependent on the nature of the
;   request.
;
;   The absoluteURI form is only allowed when the request is being made
;   to a proxy. The proxy is requested to forward the request and return
;   the response. If the request is GET or HEAD and a prior response is
;   cached, the proxy may use the cached message if it passes any
;   restrictions in the Expires header field. Note that the proxy may
;   forward the request on to another proxy or directly to the server
;   specified by the absoluteURI. In order to avoid request loops, a
;   proxy must be able to recognize all of its server names, including
;   any aliases, local variations, and the numeric IP address. An example
;   Request-Line would be:
;
;       GET http://www.w3.org/pub/WWW/TheProject.html HTTP/1.0
;
;   The most common form of Request-URI is that used to identify a
;   resource on an origin server or gateway. In this case, only the
;   absolute path of the URI is transmitted (see Section 3.2.1,
;   abs_path). For example, a client wishing to retrieve the resource
;   above directly from the origin server would create a TCP connection
;   to port 80 of the host "www.w3.org" and send the line:
;
;       GET /pub/WWW/TheProject.html HTTP/1.0
;
;   followed by the remainder of the Full-Request. Note that the absolute
;   path cannot be empty; if none is present in the original URI, it must
;   be given as "/" (the server root).
;
;   The Request-URI is transmitted as an encoded string, where some
;   characters may be escaped using the "% HEX HEX" encoding defined by
;   RFC 1738 [4]. The origin server must decode the Request-URI in order
;   to properly interpret the request.
;
; 5.2  Request Header Fields
;
;   The request header fields allow the client to pass additional
;   information about the request, and about the client itself, to the
;   server. These fields act as request modifiers, with semantics
;   equivalent to the parameters on a programming language method
;   (procedure) invocation.
;
;       Request-Header = Authorization            ; Section 10.2
;                      | From                     ; Section 10.8
;                      | If-Modified-Since        ; Section 10.9
;                      | Referer                  ; Section 10.13
;                      | User-Agent               ; Section 10.15
;
;   Request-Header field names can be extended reliably only in
;   combination with a change in the protocol version. However, new or
;   experimental header fields may be given the semantics of request
;   header fields if all parties in the communication recognize them to
;   be request header fields. Unrecognized header fields are treated as
;   Entity-Header fields.
;
; 6.  Response
;
;   After receiving and interpreting a request message, a server responds
;   in the form of an HTTP response message.
;
;       Response        = Simple-Response | Full-Response
;
;       Simple-Response = [ Entity-Body ]
;
;       Full-Response   = Status-Line             ; Section 6.1
;                         *( General-Header       ; Section 4.3
;                          | Response-Header      ; Section 6.2
;                          | Entity-Header )      ; Section 7.1
;                         CRLF
;                         [ Entity-Body ]         ; Section 7.2
;
;   A Simple-Response should only be sent in response to an HTTP/0.9
;   Simple-Request or if the server only supports the more limited
;   HTTP/0.9 protocol. If a client sends an HTTP/1.0 Full-Request and
;   receives a response that does not begin with a Status-Line, it should
;   assume that the response is a Simple-Response and parse it
;   accordingly. Note that the Simple-Response consists only of the
;   entity body and is terminated by the server closing the connection.
;
; 6.1  Status-Line
;
;   The first line of a Full-Response message is the Status-Line,
;   consisting of the protocol version followed by a numeric status code
;   and its associated textual phrase, with each element separated by SP
;   characters. No CR or LF is allowed except in the final CRLF sequence.
;
;       Status-Line = HTTP-Version SP Status-Code SP Reason-Phrase CRLF
;
;   Since a status line always begins with the protocol version and
;   status code
;
;       "HTTP/" 1*DIGIT "." 1*DIGIT SP 3DIGIT SP
;
;   (e.g., "HTTP/1.0 200 "), the presence of that expression is
;   sufficient to differentiate a Full-Response from a Simple-Response.
;   Although the Simple-Response format may allow such an expression to
;   occur at the beginning of an entity body, and thus cause a
;   misinterpretation of the message if it was given in response to a
;   Full-Request, most HTTP/0.9 servers are limited to responses of type
;   "text/html" and therefore would never generate such a response.
;
; 6.1.1 Status Code and Reason Phrase
;
;   The Status-Code element is a 3-digit integer result code of the
;   attempt to understand and satisfy the request. The Reason-Phrase is
;   intended to give a short textual description of the Status-Code. The
;   Status-Code is intended for use by automata and the Reason-Phrase is
;   intended for the human user. The client is not required to examine or
;   display the Reason-Phrase.
;
;   The first digit of the Status-Code defines the class of response. The
;   last two digits do not have any categorization role. There are 5
;   values for the first digit:
;
;      o 1xx: Informational - Not used, but reserved for future use
;
;      o 2xx: Success - The action was successfully received,
;             understood, and accepted.
;
;      o 3xx: Redirection - Further action must be taken in order to
;             complete the request
;
;      o 4xx: Client Error - The request contains bad syntax or cannot
;             be fulfilled
;
;      o 5xx: Server Error - The server failed to fulfill an apparently
;             valid request
;
;   The individual values of the numeric status codes defined for
;   HTTP/1.0, and an example set of corresponding Reason-Phrase's, are
;   presented below. The reason phrases listed here are only recommended
;   -- they may be replaced by local equivalents without affecting the
;   protocol. These codes are fully defined in Section 9.
;
;       Status-Code    = "200"   ; OK
;                      | "201"   ; Created
;                      | "202"   ; Accepted
;                      | "204"   ; No Content
;                      | "301"   ; Moved Permanently
;                      | "302"   ; Moved Temporarily
;                      | "304"   ; Not Modified
;                      | "400"   ; Bad Request
;                      | "401"   ; Unauthorized
;                      | "403"   ; Forbidden
;                      | "404"   ; Not Found
;                      | "500"   ; Internal Server Error
;                      | "501"   ; Not Implemented
;                      | "502"   ; Bad Gateway
;                      | "503"   ; Service Unavailable
;                      | extension-code
;
;       extension-code = 3DIGIT
;
;       Reason-Phrase  = *<TEXT, excluding CR, LF>
;
;   HTTP status codes are extensible, but the above codes are the only
;   ones generally recognized in current practice. HTTP applications are
;   not required to understand the meaning of all registered status
;   codes, though such understanding is obviously desirable. However,
;   applications must understand the class of any status code, as
;   indicated by the first digit, and treat any unrecognized response as
;   being equivalent to the x00 status code of that class, with the
;   exception that an unrecognized response must not be cached. For
;   example, if an unrecognized status code of 431 is received by the
;   client, it can safely assume that there was something wrong with its
;   request and treat the response as if it had received a 400 status
;   code. In such cases, user agents should present to the user the
;   entity returned with the response, since that entity is likely to
;   include human-readable information which will explain the unusual
;   status.
;
; 6.2  Response Header Fields
;
;   The response header fields allow the server to pass additional
;   information about the response which cannot be placed in the Status-
;   Line. These header fields give information about the server and about
;   further access to the resource identified by the Request-URI.
;
;       Response-Header = Location                ; Section 10.11
;                       | Server                  ; Section 10.14
;                       | WWW-Authenticate        ; Section 10.16
;
;   Response-Header field names can be extended reliably only in
;   combination with a change in the protocol version. However, new or
;   experimental header fields may be given the semantics of response
;   header fields if all parties in the communication recognize them to
;    be response header fields. Unrecognized header fields are treated as
;   Entity-Header fields.
;
; 7.  Entity
;
;   Full-Request and Full-Response messages may transfer an entity within
;   some requests and responses. An entity consists of Entity-Header
;   fields and (usually) an Entity-Body. In this section, both sender and
;   recipient refer to either the client or the server, depending on who
;   sends and who receives the entity.
;
;
; 7.1  Entity Header Fields
;
;   Entity-Header fields define optional metainformation about the
;   Entity-Body or, if no body is present, about the resource identified
;   by the request.
;
;       Entity-Header  = Allow                    ; Section 10.1
;                      | Content-Encoding         ; Section 10.3
;                      | Content-Length           ; Section 10.4
;                      | Content-Type             ; Section 10.5
;                      | Expires                  ; Section 10.7
;                      | Last-Modified            ; Section 10.10
;                      | extension-header
;
;       extension-header = HTTP-header
;
;   The extension-header mechanism allows additional Entity-Header fields
;   to be defined without changing the protocol, but these fields cannot
;   be assumed to be recognizable by the recipient. Unrecognized header
;   fields should be ignored by the recipient and forwarded by proxies.
;
; 7.2  Entity Body
;
;   The entity body (if any) sent with an HTTP request or response is in
;   a format and encoding defined by the Entity-Header fields.
;
;       Entity-Body    = *OCTET
;
;   An entity body is included with a request message only when the
;   request method calls for one. The presence of an entity body in a
;   request is signaled by the inclusion of a Content-Length header field
;   in the request message headers. HTTP/1.0 requests containing an
;   entity body must include a valid Content-Length header field.
;
;   For response messages, whether or not an entity body is included with
;   a message is dependent on both the request method and the response
;   code. All responses to the HEAD request method must not include a
;   body, even though the presence of entity header fields may lead one
;   to believe they do. All 1xx (informational), 204 (no content), and
;   304 (not modified) responses must not include a body. All other
;   responses must include an entity body or a Content-Length header
;   field defined with a value of zero (0).
;
; 7.2.1 Type
;
;   When an Entity-Body is included with a message, the data type of that
;   body is determined via the header fields Content-Type and Content-
;   Encoding. These define a two-layer, ordered encoding model:
;
;       entity-body := Content-Encoding( Content-Type( data ) )
;
;   A Content-Type specifies the media type of the underlying data. A
;   Content-Encoding may be used to indicate any additional content
;   coding applied to the type, usually for the purpose of data
;   compression, that is a property of the resource requested. The
;   default for the content encoding is none (i.e., the identity
;   function).
;
;   Any HTTP/1.0 message containing an entity body should include a
;   Content-Type header field defining the media type of that body. If
;   and only if the media type is not given by a Content-Type header, as
;   is the case for Simple-Response messages, the recipient may attempt
;   to guess the media type via inspection of its content and/or the name
;   extension(s) of the URL used to identify the resource. If the media
;   type remains unknown, the recipient should treat it as type
;   "application/octet-stream".
;
; 7.2.2 Length
;
;   When an Entity-Body is included with a message, the length of that
;   body may be determined in one of two ways. If a Content-Length header
;   field is present, its value in bytes represents the length of the
;   Entity-Body. Otherwise, the body length is determined by the closing
;   of the connection by the server.
;
;   Closing the connection cannot be used to indicate the end of a
;   request body, since it leaves no possibility for the server to send
;   back a response. Therefore, HTTP/1.0 requests containing an entity
;   body must include a valid Content-Length header field. If a request
;   contains an entity body and Content-Length is not specified, and the
;   server does not recognize or cannot calculate the length from other
;   fields, then the server should send a 400 (bad request) response.
;
;      Note: Some older servers supply an invalid Content-Length when
;      sending a document that contains server-side includes dynamically
;      inserted into the data stream. It must be emphasized that this
;      will not be tolerated by future versions of HTTP. Unless the
;      client knows that it is receiving a response from a compliant
;      server, it should not depend on the Content-Length value being
;      correct.
;
; 8.  Method Definitions
;
;   The set of common methods for HTTP/1.0 is defined below. Although
;   this set can be expanded, additional methods cannot be assumed to
;   share the same semantics for separately extended clients and servers.
;
; 8.1  GET
;
;   The GET method means retrieve whatever information (in the form of an
;   entity) is identified by the Request-URI. If the Request-URI refers
;   to a data-producing process, it is the produced data which shall be
;   returned as the entity in the response and not the source text of the
;   process, unless that text happens to be the output of the process.
;
;   The semantics of the GET method changes to a "conditional GET" if the
;   request message includes an If-Modified-Since header field. A
;   conditional GET method requests that the identified resource be
;   transferred only if it has been modified since the date given by the
;   If-Modified-Since header, as described in Section 10.9. The
;   conditional GET method is intended to reduce network usage by
;   allowing cached entities to be refreshed without requiring multiple
;   requests or transferring unnecessary data.
;
; 8.2  HEAD
;
;   The HEAD method is identical to GET except that the server must not
;   return any Entity-Body in the response. The metainformation contained
;   in the HTTP headers in response to a HEAD request should be identical
;   to the information sent in response to a GET request. This method can
;   be used for obtaining metainformation about the resource identified
;   by the Request-URI without transferring the Entity-Body itself. This
;   method is often used for testing hypertext links for validity,
;   accessibility, and recent modification.
;
;   There is no "conditional HEAD" request analogous to the conditional
;   GET. If an If-Modified-Since header field is included with a HEAD
;   request, it should be ignored.
;
; 8.3  POST
;
;   The POST method is used to request that the destination server accept
;   the entity enclosed in the request as a new subordinate of the
;   resource identified by the Request-URI in the Request-Line. POST is
;   designed to allow a uniform method to cover the following functions:
;
;      o Annotation of existing resources;
;
;      o Posting a message to a bulletin board, newsgroup, mailing list,
;        or similar group of articles;
;
;      o Providing a block of data, such as the result of submitting a
;        form [3], to a data-handling process;
;
;      o Extending a database through an append operation.
;
;   The actual function performed by the POST method is determined by the
;   server and is usually dependent on the Request-URI. The posted entity
;   is subordinate to that URI in the same way that a file is subordinate
;   to a directory containing it, a news article is subordinate to a
;   newsgroup to which it is posted, or a record is subordinate to a
;   database.
;
;   A successful POST does not require that the entity be created as a
;   resource on the origin server or made accessible for future
;   reference. That is, the action performed by the POST method might not
;   result in a resource that can be identified by a URI. In this case,
;   either 200 (ok) or 204 (no content) is the appropriate response
;   status, depending on whether or not the response includes an entity
;   that describes the result.
;
;   If a resource has been created on the origin server, the response
;   should be 201 (created) and contain an entity (preferably of type
;   "text/html") which describes the status of the request and refers to
;   the new resource.
;
;   A valid Content-Length is required on all HTTP/1.0 POST requests. An
;   HTTP/1.0 server should respond with a 400 (bad request) message if it
;   cannot determine the length of the request message's content.
;
;   Applications must not cache responses to a POST request because the
;   application has no way of knowing that the server would return an
;   equivalent response on some future request.
;
; 9.  Status Code Definitions
;
;   Each Status-Code is described below, including a description of which
;   method(s) it can follow and any metainformation required in the
;   response.
;
; 9.1  Informational 1xx
;
;   This class of status code indicates a provisional response,
;   consisting only of the Status-Line and optional headers, and is
;   terminated by an empty line. HTTP/1.0 does not define any 1xx status
;   codes and they are not a valid response to a HTTP/1.0 request.
;   However, they may be useful for experimental applications which are
;   outside the scope of this specification.
;
; 9.2  Successful 2xx
;
;   This class of status code indicates that the client's request was
;   successfully received, understood, and accepted.
;
;   200 OK
;
;   The request has succeeded. The information returned with the
;   response is dependent on the method used in the request, as follows:
;
;   GET    an entity corresponding to the requested resource is sent
;          in the response;
;
;   HEAD   the response must only contain the header information and
;          no Entity-Body;
;
;   POST   an entity describing or containing the result of the action.
;
;   201 Created
;
;   The request has been fulfilled and resulted in a new resource being
;   created. The newly created resource can be referenced by the URI(s)
;   returned in the entity of the response. The origin server should
;   create the resource before using this Status-Code. If the action
;   cannot be carried out immediately, the server must include in the
;   response body a description of when the resource will be available;
;   otherwise, the server should respond with 202 (accepted).
;
;   Of the methods defined by this specification, only POST can create a
;   resource.
;
;   202 Accepted
;
;   The request has been accepted for processing, but the processing
;   has not been completed. The request may or may not eventually be
;   acted upon, as it may be disallowed when processing actually takes
;   place. There is no facility for re-sending a status code from an
;   asynchronous operation such as this.
;
;   The 202 response is intentionally non-committal. Its purpose is to
;   allow a server to accept a request for some other process (perhaps
;   a batch-oriented process that is only run once per day) without
;   requiring that the user agent's connection to the server persist
;   until the process is completed. The entity returned with this
;   response should include an indication of the request's current
;   status and either a pointer to a status monitor or some estimate of
;   when the user can expect the request to be fulfilled.
;
;   204 No Content
;
;   The server has fulfilled the request but there is no new
;   information to send back. If the client is a user agent, it should
;   not change its document view from that which caused the request to
;   be generated. This response is primarily intended to allow input
;   for scripts or other actions to take place without causing a change
;   to the user agent's active document view. The response may include
;   new metainformation in the form of entity headers, which should
;   apply to the document currently in the user agent's active view.
;
; 9.3  Redirection 3xx
;
;   This class of status code indicates that further action needs to be
;   taken by the user agent in order to fulfill the request. The action
;   required may be carried out by the user agent without interaction
;   with the user if and only if the method used in the subsequent
;   request is GET or HEAD. A user agent should never automatically
;   redirect a request more than 5 times, since such redirections usually
;   indicate an infinite loop.
;
;   300 Multiple Choices
;
;   This response code is not directly used by HTTP/1.0 applications,
;   but serves as the default for interpreting the 3xx class of
;   responses.
;
;   The requested resource is available at one or more locations.
;   Unless it was a HEAD request, the response should include an entity
;   containing a list of resource characteristics and locations from
;   which the user or user agent can choose the one most appropriate.
;   If the server has a preferred choice, it should include the URL in
;   a Location field; user agents may use this field value for
;   automatic redirection.
;
;   301 Moved Permanently
;
;   The requested resource has been assigned a new permanent URL and
;   any future references to this resource should be done using that
;   URL. Clients with link editing capabilities should automatically
;   relink references to the Request-URI to the new reference returned
;   by the server, where possible.
;
;   The new URL must be given by the Location field in the response.
;   Unless it was a HEAD request, the Entity-Body of the response
;   should contain a short note with a hyperlink to the new URL.
;
;   If the 301 status code is received in response to a request using
;   the POST method, the user agent must not automatically redirect the
;   request unless it can be confirmed by the user, since this might
;   change the conditions under which the request was issued.
;
;       Note: When automatically redirecting a POST request after
;       receiving a 301 status code, some existing user agents will
;       erroneously change it into a GET request.
;
;   302 Moved Temporarily
;
;   The requested resource resides temporarily under a different URL.
;   Since the redirection may be altered on occasion, the client should
;   continue to use the Request-URI for future requests.
;
;   The URL must be given by the Location field in the response. Unless
;   it was a HEAD request, the Entity-Body of the response should
;   contain a short note with a hyperlink to the new URI(s).
;
;   If the 302 status code is received in response to a request using
;   the POST method, the user agent must not automatically redirect the
;   request unless it can be confirmed by the user, since this might
;   change the conditions under which the request was issued.
;
;       Note: When automatically redirecting a POST request after
;       receiving a 302 status code, some existing user agents will
;       erroneously change it into a GET request.
;
;   304 Not Modified
;
;   If the client has performed a conditional GET request and access is
;   allowed, but the document has not been modified since the date and
;   time specified in the If-Modified-Since field, the server must
;   respond with this status code and not send an Entity-Body to the
;   client. Header fields contained in the response should only include
;   information which is relevant to cache managers or which may have
;   changed independently of the entity's Last-Modified date. Examples
;   of relevant header fields include: Date, Server, and Expires. A
;   cache should update its cached entity to reflect any new field
;   values given in the 304 response.
;
;9.4  Client Error 4xx
;
;   The 4xx class of status code is intended for cases in which the
;   client seems to have erred. If the client has not completed the
;   request when a 4xx code is received, it should immediately cease
;   sending data to the server. Except when responding to a HEAD request,
;   the server should include an entity containing an explanation of the
;   error situation, and whether it is a temporary or permanent
;   condition. These status codes are applicable to any request method.
;
;      Note: If the client is sending data, server implementations on TCP
;      should be careful to ensure that the client acknowledges receipt
;      of the packet(s) containing the response prior to closing the
;      input connection. If the client continues sending data to the
;      server after the close, the server's controller will send a reset
;      packet to the client, which may erase the client's unacknowledged
;      input buffers before they can be read and interpreted by the HTTP
;      application.
;
;   400 Bad Request
;
;   The request could not be understood by the server due to malformed
;   syntax. The client should not repeat the request without
;   modifications.
;
;   401 Unauthorized
;
;   The request requires user authentication. The response must include
;   a WWW-Authenticate header field (Section 10.16) containing a
;   challenge applicable to the requested resource. The client may
;   repeat the request with a suitable Authorization header field
;   (Section 10.2). If the request already included Authorization
;   credentials, then the 401 response indicates that authorization has
;   been refused for those credentials. If the 401 response contains
;   the same challenge as the prior response, and the user agent has
;   already attempted authentication at least once, then the user
;   should be presented the entity that was given in the response,
;   since that entity may include relevant diagnostic information. HTTP
;   access authentication is explained in Section 11.
;
;   403 Forbidden
;
;   The server understood the request, but is refusing to fulfill it.
;   Authorization will not help and the request should not be repeated.
;   If the request method was not HEAD and the server wishes to make
;   public why the request has not been fulfilled, it should describe
;   the reason for the refusal in the entity body. This status code is
;   commonly used when the server does not wish to reveal exactly why
;   the request has been refused, or when no other response is
;   applicable.
;
;   404 Not Found
;
;   The server has not found anything matching the Request-URI. No
;   indication is given of whether the condition is temporary or
;   permanent. If the server does not wish to make this information
;   available to the client, the status code 403 (forbidden) can be
;   used instead.
;
; 9.5  Server Error 5xx
;
;   Response status codes beginning with the digit "5" indicate cases in
;   which the server is aware that it has erred or is incapable of
;   performing the request. If the client has not completed the request
;   when a 5xx code is received, it should immediately cease sending data
;   to the server. Except when responding to a HEAD request, the server
;   should include an entity containing an explanation of the error
;   situation, and whether it is a temporary or permanent condition.
;   These response codes are applicable to any request method and there
;   are no required header fields.
;
;   500 Internal Server Error
;
;   The server encountered an unexpected condition which prevented it
;   from fulfilling the request.
;
;   501 Not Implemented
;
;   The server does not support the functionality required to fulfill
;   the request. This is the appropriate response when the server does
;   not recognize the request method and is not capable of supporting
;   it for any resource.
;
;   502 Bad Gateway
;
;   The server, while acting as a gateway or proxy, received an invalid
;   response from the upstream server it accessed in attempting to
;   fulfill the request.
;
;   503 Service Unavailable
;
;   The server is currently unable to handle the request due to a
;   temporary overloading or maintenance of the server. The implication
;   is that this is a temporary condition which will be alleviated
;   after some delay.
;
;       Note: The existence of the 503 status code does not imply
;       that a server must use it when becoming overloaded. Some
;       servers may wish to simply refuse the connection.
;
; 10.  Header Field Definitions
;
;   This section defines the syntax and semantics of all commonly used
;   HTTP/1.0 header fields. For general and entity header fields, both
;   sender and recipient refer to either the client or the server,
;   depending on who sends and who receives the message.
;
; 10.1  Allow
;
;   The Allow entity-header field lists the set of methods supported by
;   the resource identified by the Request-URI. The purpose of this field
;   is strictly to inform the recipient of valid methods associated with
;   the resource. The Allow header field is not permitted in a request
;   using the POST method, and thus should be ignored if it is received
;   as part of a POST entity.
;
;       Allow          = "Allow" ":" 1#method
;
;    Example of use:
;
;       Allow: GET, HEAD
;
;   This field cannot prevent a client from trying other methods.
;   However, the indications given by the Allow header field value should
;   be followed. The actual set of allowed methods is defined by the
;   origin server at the time of each request.
;
;   A proxy must not modify the Allow header field even if it does not
;   understand all the methods specified, since the user agent may have
;   other means of communicating with the origin server.
;
;   The Allow header field does not indicate what methods are implemented
;   by the server.
;
; 10.2  Authorization
;
;   A user agent that wishes to authenticate itself with a server--
;   usually, but not necessarily, after receiving a 401 response--may do
;   so by including an Authorization request-header field with the
;   request. The Authorization field value consists of credentials
;   containing the authentication information of the user agent for the
;   realm of the resource being requested.
;
;       Authorization  = "Authorization" ":" credentials
;
;   HTTP access authentication is described in Section 11. If a request
;   is authenticated and a realm specified, the same credentials should
;   be valid for all other requests within this realm.
;
;   Responses to requests containing an Authorization field are not
;   cachable.
;
; 10.3  Content-Encoding
;
;   The Content-Encoding entity-header field is used as a modifier to the
;   media-type. When present, its value indicates what additional content
;   coding has been applied to the resource, and thus what decoding
;   mechanism must be applied in order to obtain the media-type
;   referenced by the Content-Type header field. The Content-Encoding is
;   primarily used to allow a document to be compressed without losing
;   the identity of its underlying media type.
;
;       Content-Encoding = "Content-Encoding" ":" content-coding
;
;   Content codings are defined in Section 3.5. An example of its use is
;
;       Content-Encoding: x-gzip
;
;   The Content-Encoding is a characteristic of the resource identified
;   by the Request-URI. Typically, the resource is stored with this
;   encoding and is only decoded before rendering or analogous usage.
;
; 10.4  Content-Length
;
;   The Content-Length entity-header field indicates the size of the
;   Entity-Body, in decimal number of octets, sent to the recipient or,
;   in the case of the HEAD method, the size of the Entity-Body that
;   would have been sent had the request been a GET.
;
;       Content-Length = "Content-Length" ":" 1*DIGIT
;
;   An example is
;
;       Content-Length: 3495
;
;   Applications should use this field to indicate the size of the
;   Entity-Body to be transferred, regardless of the media type of the
;   entity. A valid Content-Length field value is required on all
;   HTTP/1.0 request messages containing an entity body.
;
;   Any Content-Length greater than or equal to zero is a valid value.
;   Section 7.2.2 describes how to determine the length of a response
;   entity body if a Content-Length is not given.
;
;      Note: The meaning of this field is significantly different from
;      the corresponding definition in MIME, where it is an optional
;      field used within the "message/external-body" content-type. In
;      HTTP, it should be used whenever the entity's length can be
;      determined prior to being transferred.
;
; 10.5  Content-Type
;
;   The Content-Type entity-header field indicates the media type of the
;   Entity-Body sent to the recipient or, in the case of the HEAD method,
;   the media type that would have been sent had the request been a GET.
;
;       Content-Type   = "Content-Type" ":" media-type
;
;   Media types are defined in Section 3.6. An example of the field is
;
;       Content-Type: text/html
;
;   Further discussion of methods for identifying the media type of an
;   entity is provided in Section 7.2.1.
;
; 10.6  Date
;
;   The Date general-header field represents the date and time at which
;   the message was originated, having the same semantics as orig-date in
;   RFC 822. The field value is an HTTP-date, as described in Section
;   3.3.
;
;       Date           = "Date" ":" HTTP-date
;
;   An example is
;
;       Date: Tue, 15 Nov 1994 08:12:31 GMT
;
;   If a message is received via direct connection with the user agent
;   (in the case of requests) or the origin server (in the case of
;   responses), then the date can be assumed to be the current date at
;   the receiving end. However, since the date--as it is believed by the
;   origin--is important for evaluating cached responses, origin servers
;   should always include a Date header. Clients should only send a Date
;   header field in messages that include an entity body, as in the case
;   of the POST request, and even then it is optional. A received message
;   which does not have a Date header field should be assigned one by the
;   recipient if the message will be cached by that recipient or
;   gatewayed via a protocol which requires a Date.
;
;   In theory, the date should represent the moment just before the
;   entity is generated. In practice, the date can be generated at any
;   time during the message origination without affecting its semantic
;   value.
;
;      Note: An earlier version of this document incorrectly specified
;      that this field should contain the creation date of the enclosed
;      Entity-Body. This has been changed to reflect actual (and proper)
;      usage.
;
; 10.7  Expires
;
;   The Expires entity-header field gives the date/time after which the
;   entity should be considered stale. This allows information providers
;   to suggest the volatility of the resource, or a date after which the
;   information may no longer be valid. Applications must not cache this
;   entity beyond the date given. The presence of an Expires field does
;   not imply that the original resource will change or cease to exist
;   at, before, or after that time. However, information providers that
;   know or even suspect that a resource will change by a certain date
;   should include an Expires header with that date. The format is an
;   absolute date and time as defined by HTTP-date in Section 3.3.
;
;       Expires        = "Expires" ":" HTTP-date
;
;   An example of its use is
;
;       Expires: Thu, 01 Dec 1994 16:00:00 GMT
;
;   If the date given is equal to or earlier than the value of the Date
;   header, the recipient must not cache the enclosed entity. If a
;   resource is dynamic by nature, as is the case with many data-
;   producing processes, entities from that resource should be given an
;   appropriate Expires value which reflects that dynamism.
;
;   The Expires field cannot be used to force a user agent to refresh its
;   display or reload a resource; its semantics apply only to caching
;   mechanisms, and such mechanisms need only check a resource's
;   expiration status when a new request for that resource is initiated.
;
;   User agents often have history mechanisms, such as "Back" buttons and
;   history lists, which can be used to redisplay an entity retrieved
;   earlier in a session. By default, the Expires field does not apply to
;   history mechanisms. If the entity is still in storage, a history
;   mechanism should display it even if the entity has expired, unless
;   the user has specifically configured the agent to refresh expired
;   history documents.
;
;      Note: Applications are encouraged to be tolerant of bad or
;      misinformed implementations of the Expires header. A value of zero
;      (0) or an invalid date format should be considered equivalent to
;      an "expires immediately." Although these values are not legitimate
;      for HTTP/1.0, a robust implementation is always desirable.
;
; 10.8  From
;
;   The From request-header field, if given, should contain an Internet
;   e-mail address for the human user who controls the requesting user
;   agent. The address should be machine-usable, as defined by mailbox in
;   RFC 822 [7] (as updated by RFC 1123 [6]):
;
;       From           = "From" ":" mailbox
;
;   An example is:
;
;       From: webmaster@w3.org
;
;   This header field may be used for logging purposes and as a means for
;   identifying the source of invalid or unwanted requests. It should not
;   be used as an insecure form of access protection. The interpretation
;   of this field is that the request is being performed on behalf of the
;   person given, who accepts responsibility for the method performed. In
;   particular, robot agents should include this header so that the
;   person responsible for running the robot can be contacted if problems
;   occur on the receiving end.
;
;   The Internet e-mail address in this field may be separate from the
;   Internet host which issued the request. For example, when a request
;   is passed through a proxy, the original issuer's address should be
;   used.
;
;      Note: The client should not send the From header field without the
;      user's approval, as it may conflict with the user's privacy
;      interests or their site's security policy. It is strongly
;      recommended that the user be able to disable, enable, and modify
;      the value of this field at any time prior to a request.
;
; 10.9  If-Modified-Since
;
;   The If-Modified-Since request-header field is used with the GET
;   method to make it conditional: if the requested resource has not been
;   modified since the time specified in this field, a copy of the
;   resource will not be returned from the server; instead, a 304 (not
;   modified) response will be returned without any Entity-Body.
;
;       If-Modified-Since = "If-Modified-Since" ":" HTTP-date
;
;   An example of the field is:
;
;       If-Modified-Since: Sat, 29 Oct 1994 19:43:31 GMT
;
;   A conditional GET method requests that the identified resource be
;   transferred only if it has been modified since the date given by the
;   If-Modified-Since header. The algorithm for determining this includes
;   the following cases:
;
;      a) If the request would normally result in anything other than
;         a 200 (ok) status, or if the passed If-Modified-Since date
;         is invalid, the response is exactly the same as for a
;         normal GET. A date which is later than the server's current
;         time is invalid.
;
;      b) If the resource has been modified since the
;         If-Modified-Since date, the response is exactly the same as
;         for a normal GET.
;
;      c) If the resource has not been modified since a valid
;         If-Modified-Since date, the server shall return a 304 (not
;         modified) response.
;
;   The purpose of this feature is to allow efficient updates of cached
;   information with a minimum amount of transaction overhead.
;
; 10.10  Last-Modified
;
;   The Last-Modified entity-header field indicates the date and time at
;   which the sender believes the resource was last modified. The exact
;   semantics of this field are defined in terms of how the recipient
;   should interpret it:  if the recipient has a copy of this resource
;   which is older than the date given by the Last-Modified field, that
;   copy should be considered stale.
;
;       Last-Modified  = "Last-Modified" ":" HTTP-date
;
;   An example of its use is
;
;       Last-Modified: Tue, 15 Nov 1994 12:45:26 GMT
;
;   The exact meaning of this header field depends on the implementation
;   of the sender and the nature of the original resource. For files, it
;   may be just the file system last-modified time. For entities with
;   dynamically included parts, it may be the most recent of the set of
;   last-modify times for its component parts. For database gateways, it
;   may be the last-update timestamp of the record. For virtual objects,
;   it may be the last time the internal state changed.
;
;   An origin server must not send a Last-Modified date which is later
;   than the server's time of message origination. In such cases, where
;   the resource's last modification would indicate some time in the
;   future, the server must replace that date with the message
;   origination date.
;
; 10.11  Location
;
;   The Location response-header field defines the exact location of the
;   resource that was identified by the Request-URI. For 3xx responses,
;   the location must indicate the server's preferred URL for automatic
;   redirection to the resource. Only one absolute URL is allowed.
;
;       Location       = "Location" ":" absoluteURI
;
;   An example is
;
;       Location: http://www.w3.org/hypertext/WWW/NewLocation.html
;
; 10.12  Pragma
;
;   The Pragma general-header field is used to include implementation-
;   specific directives that may apply to any recipient along the
;   request/response chain. All pragma directives specify optional
;   behavior from the viewpoint of the protocol; however, some systems
;   may require that behavior be consistent with the directives.
;
;       Pragma           = "Pragma" ":" 1#pragma-directive
;
;       pragma-directive = "no-cache" | extension-pragma
;       extension-pragma = token [ "=" word ]
;
;   When the "no-cache" directive is present in a request message, an
;   application should forward the request toward the origin server even
;   if it has a cached copy of what is being requested. This allows a
;   client to insist upon receiving an authoritative response to its
;   request. It also allows a client to refresh a cached copy which is
;   known to be corrupted or stale.
;
;   Pragma directives must be passed through by a proxy or gateway
;   application, regardless of their significance to that application,
;   since the directives may be applicable to all recipients along the
;   request/response chain. It is not possible to specify a pragma for a
;   specific recipient; however, any pragma directive not relevant to a
;   recipient should be ignored by that recipient.
;
; 10.13  Referer
;
;   The Referer request-header field allows the client to specify, for
;   the server's benefit, the address (URI) of the resource from which
;   the Request-URI was obtained. This allows a server to generate lists
;   of back-links to resources for interest, logging, optimized caching,
;   etc. It also allows obsolete or mistyped links to be traced for
;   maintenance. The Referer field must not be sent if the Request-URI
;   was obtained from a source that does not have its own URI, such as
;   input from the user keyboard.
;
;       Referer        = "Referer" ":" ( absoluteURI | relativeURI )
;
;   Example:
;
;       Referer: http://www.w3.org/hypertext/DataSources/Overview.html
;
;   If a partial URI is given, it should be interpreted relative to the
;   Request-URI. The URI must not include a fragment.
;
;      Note: Because the source of a link may be private information or
;      may reveal an otherwise private information source, it is strongly
;      recommended that the user be able to select whether or not the
;      Referer field is sent. For example, a browser client could have a
;      toggle switch for browsing openly/anonymously, which would
;      respectively enable/disable the sending of Referer and From
;      information.
;
; 10.14  Server
;
;   The Server response-header field contains information about the
;   software used by the origin server to handle the request. The field
;   can contain multiple product tokens (Section 3.7) and comments
;   identifying the server and any significant subproducts. By
;   convention, the product tokens are listed in order of their
;   significance for identifying the application.
;
;       Server         = "Server" ":" 1*( product | comment )
;
;   Example:
;
;       Server: CERN/3.0 libwww/2.17
;
;   If the response is being forwarded through a proxy, the proxy
;   application must not add its data to the product list.
;
;      Note: Revealing the specific software version of the server may
;      allow the server machine to become more vulnerable to attacks
;      against software that is known to contain security holes. Server
;      implementors are encouraged to make this field a configurable
;      option.
;
;      Note: Some existing servers fail to restrict themselves to the
;      product token syntax within the Server field.
;
; 10.15  User-Agent
;
;   The User-Agent request-header field contains information about the
;   user agent originating the request. This is for statistical purposes,
;   the tracing of protocol violations, and automated recognition of user
;   agents for the sake of tailoring responses to avoid particular user
;   agent limitations. Although it is not required, user agents should
;   include this field with requests. The field can contain multiple
;   product tokens (Section 3.7) and comments identifying the agent and
;   any subproducts which form a significant part of the user agent. By
;   convention, the product tokens are listed in order of their
;   significance for identifying the application.
;
;       User-Agent     = "User-Agent" ":" 1*( product | comment )
;
;   Example:
;
;       User-Agent: CERN-LineMode/2.15 libwww/2.17b3
;
;       Note: Some current proxy applications append their product
;       information to the list in the User-Agent field. This is not
;       recommended, since it makes machine interpretation of these
;       fields ambiguous.
;
;       Note: Some existing clients fail to restrict themselves to
;       the product token syntax within the User-Agent field.
;
; 10.16  WWW-Authenticate
;
;   The WWW-Authenticate response-header field must be included in 401
;   (unauthorized) response messages. The field value consists of at
;   least one challenge that indicates the authentication scheme(s) and
;   parameters applicable to the Request-URI.
;
;       WWW-Authenticate = "WWW-Authenticate" ":" 1#challenge
;
;   The HTTP access authentication process is described in Section 11.
;   User agents must take special care in parsing the WWW-Authenticate
;   field value if it contains more than one challenge, or if more than
;   one WWW-Authenticate header field is provided, since the contents of
;   a challenge may itself contain a comma-separated list of
;   authentication parameters.
				;
				;
				;
; D.  Additional Features
;
;   This appendix documents protocol elements used by some existing HTTP
;   implementations, but not consistently and correctly across most
;   HTTP/1.0 applications. Implementors should be aware of these
;   features, but cannot rely upon their presence in, or interoperability
;   with, other HTTP/1.0 applications.
;
; D.1  Additional Request Methods
;
; D.1.1 PUT
;
;   The PUT method requests that the enclosed entity be stored under the
;   supplied Request-URI. If the Request-URI refers to an already
;   existing resource, the enclosed entity should be considered as a
;   modified version of the one residing on the origin server. If the
;   Request-URI does not point to an existing resource, and that URI is
;   capable of being defined as a new resource by the requesting user
;   agent, the origin server can create the resource with that URI.
;
;   The fundamental difference between the POST and PUT requests is
;   reflected in the different meaning of the Request-URI. The URI in a
;   POST request identifies the resource that will handle the enclosed
;   entity as data to be processed. That resource may be a data-accepting
;   process, a gateway to some other protocol, or a separate entity that
;   accepts annotations. In contrast, the URI in a PUT request identifies
;   the entity enclosed with the request -- the user agent knows what URI
;   is intended and the server should not apply the request to some other
;   resource.
;
; D.1.2 DELETE
;
;   The DELETE method requests that the origin server delete the resource
;   identified by the Request-URI.
;
; D.1.3 LINK
;
;   The LINK method establishes one or more Link relationships between
;   the existing resource identified by the Request-URI and other
;   existing resources.
;
; D.1.4 UNLINK
;
;   The UNLINK method removes one or more Link relationships from the
;   existing resource identified by the Request-URI.
;
; D.2  Additional Header Field Definitions
;
; D.2.1 Accept
;
;   The Accept request-header field can be used to indicate a list of
;   media ranges which are acceptable as a response to the request. The
;   asterisk "*" character is used to group media types into ranges, with
;   "*/*" indicating all media types and "type/*" indicating all subtypes
;   of that type. The set of ranges given by the client should represent
;   what types are acceptable given the context of the request.
;
; D.2.2 Accept-Charset
;
;   The Accept-Charset request-header field can be used to indicate a
;   list of preferred character sets other than the default US-ASCII and
;   ISO-8859-1. This field allows clients capable of understanding more
;   comprehensive or special-purpose character sets to signal that
;   capability to a server which is capable of representing documents in
;   those character sets.
;
; D.2.3 Accept-Encoding
;
;   The Accept-Encoding request-header field is similar to Accept, but
;   restricts the content-coding values which are acceptable in the
;   response.
;
; D.2.4 Accept-Language
;
;   The Accept-Language request-header field is similar to Accept, but
;   restricts the set of natural languages that are preferred as a
;   response to the request.
;
; D.2.5 Content-Language
;
;   The Content-Language entity-header field describes the natural
;   language(s) of the intended audience for the enclosed entity. Note
;   that this may not be equivalent to all the languages used within the
;   entity.
;
; D.2.6 Link
;
;   The Link entity-header field provides a means for describing a
;   relationship between the entity and some other resource. An entity
;   may include multiple Link values. Links at the metainformation level
;   typically indicate relationships like hierarchical structure and
;   navigation paths.
;
; D.2.7 MIME-Version
;
;   HTTP messages may include a single MIME-Version general-header field
;   to indicate what version of the MIME protocol was used to construct
;   the message. Use of the MIME-Version header field, as defined by RFC
;   1521 [5], should indicate that the message is MIME-conformant.
;   Unfortunately, some older HTTP/1.0 servers send it indiscriminately,
;   and thus this field should be ignored.
;
; D.2.8 Retry-After
;
;   The Retry-After response-header field can be used with a 503 (service
;   unavailable) response to indicate how long the service is expected to
;   be unavailable to the requesting client. The value of this field can
;   be either an HTTP-date or an integer number of seconds (in decimal)
;   after the time of the response.
;
; D.2.9 Title
;
;   The Title entity-header field indicates the title of the entity.
;
; D.2.10 URI
;
;   The URI entity-header field may contain some or all of the Uniform
;   Resource Identifiers (Section 3.2) by which the Request-URI resource
;   can be identified. There is no guarantee that the resource can be
;   accessed using the URI(s) specified.
;
;==============================================================================
;
HTTP_SOCKET	equ	3
HTTP_PORT	equ	80		; Dest port always 80 for HTTP protocol
;
;
; This is the data kept in EXOS channel RAM.
;
; EXOS channel RAM is accessed at (ix-1), (ix-2)...etc so our data here is
; accessed with (ix-1-<item>) eg (ix-1-http_channel.socket). But it must
; first be paged into page 1 - the page in kept in L'.
;
; socket must be first as some of the generic device code expects it here.
;
		struct	http_channel	; Variables in EXOS channel RAM
socket		 byte			; WIZ socket # for this channel
size_H		 byte			; File size
size_L		 byte
		ends
;
;
;------------------------------------------------------------------------------
; device_open
;
; This implements the open code for the EXOS device.
;
; In:  vars.device.ip = ip address
;      DE->"filename", NOT null terminated
;       B=length of filename
; Out: A=EXOS error code
;
device_open:
		exx
		out	(c),l		; Channel RAM page
		ld	 (ix-1-http_channel.socket),HTTP_SOCKET
		out	(c),b		; Back to our page
		exx
;
		bit	vars.trace.http,(iy+vars._trace)
		jr	z,.donetrace
;
		push	de
		push	bc
		 ld	de,trace.http.open
		 call	trace
;
		 ld	hl,vars.device.ip; DE->ip address
		 call	io.ip
		 ld	a,':'
		 call	io.char
		 ld	a,HTTP_PORT
		 call	io.short
		pop	bc
		pop	de
;
.donetrace:	call	status.start

		push	de
		push	bc
		 ld	hl,42		; Source port
;
		 exx
		 out	(c),l		; Channel RAM page
		 ld	a,(ix-1-http_channel.socket)	; Get socket number
		 out	(c),b		; Back to our page
		 exx
;
		 ld	de,owner_str	; Our name
		 push	af		; Save socket number
		  call	tcp.open
		 pop	bc		; B=socket number
		 ld	a,b		; A=socket number without corrupting F
		 ld	hl,HTTP_PORT	; HL=dest port
		 ld	de,vars.device.ip; DE->ip address
		 call	nc,tcp.connect	; Connect to server
		 sbc	a,a		; Error (Cy)->FF, no error (NC)->0
		 and	exos.ERR_NOCON	; Error & NZ or 0 & Z
		pop	bc
		pop	de
		jr	nz,.ret		; Go if error
;
		call	send		; Send a "GET" request
		jr	nz,.ret
;
		; We should get an HTTP reply, which consists of a header
		; with a variable number of variable length ASCII lines ending
		; in CR,LF. The end of the header is marked by a blank line
		; (ie a double CR,LF pair). Assuming the retirn code is
		; 200 OK the file itself should follow the header.
		call	readline	; Get first header line
		or	a
		jr	nz,.ret
;
		ld	de,http_1.0_str	; Make sure it starts with HTTP...
		ld	b,http_1.0_str_len
		call	util.memcmp
		jr	nz,.badpacket
;
.unspace:	inc	hl
		ld	a,(hl)			; Skip spaces
		cp	' '
		jr	z,.unspace
;
		; Next should come the response code
		ex	de,hl		; DE->code in packet
		call	util.get_num16
		bit	vars.trace.http,(iy+vars._trace)
		jr	z,.donecodetrace
;
		ld	de,trace.http.code
		call	trace
		push	hl
		 call	io.int
		pop	hl
;		
.donecodetrace:	ld	bc,200		; Should be "200 OK"
		or	a
		sbc	hl,bc
		jr	z,.nextline
;
		or	a
		ld	bc,404-200	; 404 => not found
		sbc	hl,bc
		ld	a,exos.ERR_NOFIL
		jr	z,.ret
;
.badpacket:	ld	a,exos.ERR_BADHTTP
.ret:		push	af
		 call	status.stop
		pop	af
		ret
;
		; Now we read and discard all other lines until we reach the
		; end of the header
.nextline:	call	readline
		or	a
		jr	nz,.ret
;
		ld	a,(hl)		; See if blank line
		or	a
		jr	z,.ret		; Finished reading header if yes
;
		ld	de,content_length_str	; See if length field
		ld	b,content_length_str_len
		call	util.memcmp
		jr	nz,.nextline		; Go & read naext line if not
;
.unspace2:	inc	hl			; Skip spaces after
		ld	a,(hl)
		cp	' '
		jr	z,.unspace2
;
		ex	de,hl			; DE->length in packet
		call	util.get_num16		; HL=size
;
		; Save size to channel RAM
		push	hl
		 exx
		 out	(c),l			; Channel RAM page
		pop	hl			; HL=size
		ld	(ix-1-http_channel.size_L),l; Save size of packet body
		ld	(ix-1-http_channel.size_H),h
		in	l,(c)			; Restore seg normally in L'
		out	(c),b			; Back to our page
		exx
;
		bit	vars.trace.http,(iy+vars._trace)
		jr	z,.donelentrace
;
		ld	de,trace.http.size	; Print size read from packet
		call	trace
		call	io.int
;
.donelentrace:	jr	.nextline		; Finish reading header
;
;

; Out: HL->vars.http.packet
;
readline:
		ld	de,vars.http.packet
		push	de
		 dec	de		; Compensate for initial inc de
;
.next:		 inc	de
.ignore:	 push	de		; Save ->current byte
		  ld	bc,1		; Read 1 byte
;
		  exx
		  out	(c),l		; Channel RAM page
		  ld	a,(ix-1-http_channel.socket)
		  out	(c),b		; Back to our page
		  exx
;
		  call	tcp.read_block
		 pop	de		; DE->current byte
		 jr	c,.err
;
		 ld	a,(de)
		 cp	CR		; Just ignore CRs
		 jr	z,.ignore
;
		 sub	LF		; End of line?
		 jr	nz,.next	; Read next char if not
;
		 ld	(de),a		; Turn into a null-terminated string
;
		 bit	vars.trace.http,(iy+vars._trace)
		 jr	z,.donetrace
;
		 ld	de,trace.http.rx
		 call	trace
;
		pop	de
		push	de
		 call	io.str
;
.donetrace:	pop	hl		; Return HL->line
		xor	a		; No error
		ret
;
.err:		pop	hl
;
		bit	vars.trace.http,(iy+vars._trace)
		jr	z,.donetrace3
;
		push	af
		 call	c,trace.error
		pop	af
;
.donetrace3:
		sub	2
		ld	a,exos.ERR_EOF
		ret	m		; Code 1=>socket closed
;
		ld	a,exos.ERR_STOP
		ret	z		; Code 2=>STOP pressed
;
		ld	a,exos.ERR_TIMEOUT	; Code 3=>timeout
		ret
;
;
;------------------------------------------------------------------------------
; send
;
; sends an HTTP "GET" request.
;
; DE->"filename", no null
; B=length of filename
;
send:		push	de
		push	bc
		 ld	de,vars.http.packet	; Build packet here
;
		 ld	hl,get_str	; "GET "
		 ld	bc,get_str_len
		 ldir			; Copy GET to packet
		pop	bc		; B="filename" length
		pop	hl		; HL->"filename"
;
		ld	c,b		; C=length
		xor	a
		ld	b,a		; BC=length
		or	c
		jr	z,.donefn	; Just in case!
;
		ldir			; Copy filename to packet
.donefn:	ld	hl,_http_header_str	; " HTTP/1.0" etc
		ld	bc,_http_header_str_len
		ldir			; Copy protocol etc to packet
;
		ld	hl,vars.device.host
		call	util.copystr	; Copy host name to packet
;
		ex	de,hl		; HL->end of packet
;
		bit	vars.trace.http,(iy+vars._trace)
		jr	z,.donetrace
;
		ld	(hl),0		; Null terminate so we can print it
;
		ld	de,vars.http.packet
.loop:		push	de		; Save ->string in packet
		 ld	de,trace.http.tx
		 call	trace		; Start trace line
		pop	de		; DE->string in packet
		call	io.line		; Print one line
		ld	a,(de)		; See if more lines
		or	a
		jr	nz,.loop	; Print if yes
;
		call	trace.dots
;
.donetrace:	ld	(hl),CR		; Add CR,LF now we've done trace
		inc	hl
		ld	(hl),LF
		inc	hl
;
		ld	(hl),CR		; Add final CR, LF to mark end of header
		inc	hl
		ld	(hl),LF
		inc	hl
;
		ld	de,vars.http.packet	; DE->start of packet
		or	a
		sbc	hl,de		; HL=length of packet
		ld	c,l
		ld	b,h		; BC=length of packet
		ex	de,hl		; HL->packet
;
		exx
		out	(c),l		; Channel RAM page
		ld	a,(ix-1-http_channel.socket)	; Gert socket number
		out	(c),b		; Back to our page
		exx
;
		push	af		; Save socket number
		call	socket.write
		pop	bc		; B=socket number
		ld	a,b		; A=socket number without corrupting Cy
		call	nc,tcp.send
;
		bit	vars.trace.http,(iy+vars._trace)
		jr	z,.dt2
;
		call	trace.is_error
;
.dt2:		sbc	a,a
		and	exos.ERR_TIMEOUT
		ret
;
;
;------------------------------------------------------------------------------
; trace
;
; Starts a line of trace output
;
; In:  DE->str
;
trace:		call	io.start
		ld	a,'H'
		call	io.char
		ld	a,'T'
		call	io.char
		ld	a,'T'
		call	io.char
		ld	a,'P'
		call	io.char
		exx
		out	(c),l		; Channel RAM page
		ld	a,(ix-1-http_channel.socket)
		out	(c),b		; Back to our page
		exx
		add	a,'0'
		call	io.char
		ld	a,':'
		call	io.char
		jp	io.str
;
;
get_str:	db	"GET "
get_str_len	equ	$-get_str
;
_http_header_str:db	" "
http_1.0_str:	db	"HTTP/1.0"
http_1.0_str_len equ	$-http_1.0_str
		db	CR,LF
		db	"Connection: Close",CR,LF
		db	"User-Agent: Z80 Enterprise EPNET/"
		db	version.major, ".", version.minor, version.revision,CR,LF
		db	"Host: "
_http_header_str_len equ	$-_http_header_str
;
content_length_str:	db	"Content-Length"
content_length_str_len	equ	$-content_length_str
;
;
owner_str:	db	"HTTP:",0
;
;
;
		endmodule
