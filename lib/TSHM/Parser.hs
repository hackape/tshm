module TSHM.Parser where

import           Control.Monad.Combinators.Expr (Operator (..), makeExprParser)
import           Data.List                      (foldr1)
import           Data.Void                      ()
import           Prelude
import           TSHM.TypeScript
import           Text.Megaparsec                hiding (many, some)
import           Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer     as L

type Parser = Parsec Void String

operators :: [[Operator Parser TsType]]
operators =
  [ [ Postfix (multi
      (   (TsTypeGeneric "Array" . pure <$ string "[]")
      <|> (flip TsTypeObjectReference <$> between (char '[') (char ']') pStringLiteral)
      )
    )]
  , [ Prefix (TsTypeKeysOf <$ string "keyof ")
    ]
  , [ binary "&" (TsTypeExpression TsOperatorIntersection)
    , binary "|" (TsTypeExpression TsOperatorUnion)
    ]
  ]
    where multi :: Alternative f => f (a -> a) -> f (a -> a)
          multi f = foldr1 (flip (.)) <$> some f

          binary :: String -> (TsType -> TsType -> TsType) -> Operator Parser TsType
          binary x f = InfixR $ f <$ string (" " <> x <> " ")

pType :: Parser TsType
pType = (`makeExprParser` operators) $ choice
  [ try $ TsTypeGrouped <$> between (char '(') (char ')') pType
  , TsTypeVoid <$ string "void"
  , TsTypeNull <$ string "null"
  , TsTypeUndefined <$ string "undefined"
  , TsTypeBoolean <$> ((True <$ string "true") <|> (False <$ string "false"))
  , TsTypeStringLiteral <$> pStringLiteral
  , TsTypeNumberLiteral <$> pNumberLiteral
  , TsTypeTuple <$> pTuple
  , TsTypeObject <$> pObject
  , TsTypeFunction <$> pFunction
  , try pGeneric
  , TsTypeReflection <$> (string "typeof " *> some alphaNumChar)
  , TsTypeMisc <$> pTypeMisc
  ]

pTypeMisc :: Parser String
pTypeMisc = some alphaNumChar

pGeneric :: Parser TsType
pGeneric = TsTypeGeneric <$> pTypeMisc <*> pTypeArgs

pStringLiteral :: Parser String
pStringLiteral = stringLiteral '\'' <|> stringLiteral '"'
  where stringLiteral :: Char -> Parser String
        stringLiteral c =
          let p = char c
           in p *> manyTill L.charLiteral p

pNumberLiteral :: Parser String
pNumberLiteral = (<>) . maybe "" pure <$> optional (char '-') <*> choice
  [ try $ (\x y z -> x <> pure y <> z) <$> some numberChar <*> char '.' <*> some numberChar
  , (:) <$> char '.' <*> some numberChar
  , some numberChar
  ]

pFunction :: Parser Function
pFunction = Function <$> optional pTypeArgs <*> pParams <*> pReturn

pTuple :: Parser [TsType]
pTuple = between (char '[') (char ']') $ sepBy pType (string ", ")

pObject :: Parser [Partial (String, TsType)]
pObject = between (string "{ ") (string " }") (sepBy1 pPair (string ", " <|> string "; ")) <|> [] <$ string "{}"
  where pPair :: Parser (Partial (String, TsType))
        pPair = flip f <$> some alphaNumChar <*> (True <$ string ": " <|> False <$ string "?: ") <*> pType

        f :: Bool -> String -> TsType -> Partial (String, TsType)
        f True = (Required .) . (,)
        f False = (Optional .) . (,)

pName :: Parser String
pName = optional (string "export ") *> string "declare const " *> some alphaNumChar <* string ": "

pTypeArgs :: Parser [TsType]
pTypeArgs = between (char '<') (char '>') (sepBy1 pTypeArg (string ", "))
  where pTypeArg :: Parser TsType
        pTypeArg = choice
          [ try $ TsTypeSubtype <$> pTypeMisc <* string " extends " <*> pType
          , pType
          ]

pParams :: Parser [Param]
pParams = between (char '(') (char ')') $ sepBy pParam (string ", ")
  where pParam :: Parser Param
        pParam = f <$> (isJust <$> optional (string "...")) <*> (some alphaNumChar *> string ": " *> optional (string "new ") *> pType)

        f :: Bool -> TsType -> Param
        f True = Rest
        f False = Normal

pReturn :: Parser TsType
pReturn = string " => " *> pType

pDeclaration :: Parser Declaration
pDeclaration = Declaration <$> pName <*> pType <* optional (char ';') <* eof

parseDeclaration :: String -> ParseOutput
parseDeclaration = parse pDeclaration "input"

type ParseOutput = Either (ParseErrorBundle String Void) Declaration

